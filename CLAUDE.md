# Claude Maintenance Guide for ollama-cuda

This document provides instructions for maintaining the ollama-cuda repository, including updating to new Ollama versions, verifying fixes, and creating releases.

## Repository Overview

**Purpose:** Custom Ollama build with CUDA support for RTX 5090 (Blackwell architecture, compute capability 12.0) that works on non-NixOS systems.

**Key Problem Solved:** The upstream nixpkgs `ollama-cuda` package has stub library paths in RUNPATH that prevent GPU detection on non-NixOS systems. This build removes those stub paths, allowing Flox's LD_AUDIT mechanism (or pure Nix builds) to properly redirect to system NVIDIA drivers.

## Architecture

### Two Build Paths

1. **Flox Build** (`.flox/pkgs/ollama-cuda/default.nix`)
   - For non-NixOS development environments
   - Uses LD_AUDIT for system library redirection
   - Build command: `flox build ollama-cuda`

2. **Nix Flake** (`flake.nix`)
   - For pure Nix builds and NixOS
   - Hermetic, reproducible with lock file
   - Build command: `nix build`

Both use **identical RUNPATH fix logic** in the `preInstallCheck` phase.

## The Critical Fix

### Root Cause
`libggml-cuda.so` has `/nix/store/.../cuda_cudart-12.8.90-stubs/lib` in RUNPATH, causing the dynamic linker to find a 103KB stub library before the 92MB real driver at `/usr/lib/x86_64-linux-gnu/libcuda.so.1`.

### Fix Location
Both `.flox/pkgs/ollama-cuda/default.nix` and `flake.nix` contain this in `preInstallCheck`:

```nix
preInstallCheck = ''
  echo "=== Removing stub paths from libggml-cuda.so RUNPATH ==="

  if [ -f "$out/lib/ollama/libggml-cuda.so" ]; then
    OLD_RUNPATH=$(patchelf --print-rpath "$out/lib/ollama/libggml-cuda.so")
    echo "Original RUNPATH: $OLD_RUNPATH"

    # Filter out stub paths
    NEW_RUNPATH=$(echo "$OLD_RUNPATH" | tr ':' '\n' | grep -v "stubs" | tr '\n' ':' | sed 's/:$//')

    echo "New RUNPATH (stubs removed): $NEW_RUNPATH"
    patchelf --set-rpath "$NEW_RUNPATH" "$out/lib/ollama/libggml-cuda.so"

    # Verify the change
    FINAL_RUNPATH=$(patchelf --print-rpath "$out/lib/ollama/libggml-cuda.so")
    echo "Final RUNPATH: $FINAL_RUNPATH"

    if echo "$FINAL_RUNPATH" | grep -q "stubs"; then
      echo "ERROR: Stub paths still present!"
      exit 1
    else
      echo "SUCCESS: Stub paths removed"
    fi
  fi
'';
```

**Note:** In `flake.nix`, patchelf is called with `${pkgs.patchelf}/bin/patchelf` for full path reference. In Flox, `patchelf` is directly available.

**Why preInstallCheck?** It runs AFTER `autoPatchelfHook` completes during the fixupPhase. If we use `postFixup`, autoPatchelfHook runs last and re-adds the stub paths.

## Updating to New Ollama Versions

### Step 1: Update nixpkgs

For **Flox**:
```bash
flox update
```

For **Nix Flake**:
```bash
nix flake update
```

This pulls the latest nixpkgs, which may include a newer Ollama version.

### Step 2: Check Upstream Version

```bash
# For Flox (from within flox activate)
nix-env -qa ollama-cuda

# For Nix flake
nix eval nixpkgs#ollama-cuda.version
```

### Step 3: Rebuild Both Paths

**Flox:**
```bash
flox build ollama-cuda
```

**Nix Flake:**
```bash
nix build --extra-experimental-features 'nix-command flakes' -L
```

Watch build logs for: `SUCCESS: Stub paths removed`

### Step 4: Verify the Fix

**Check RUNPATH** (both builds):
```bash
# For Flox build
readelf -d result-ollama-cuda/lib/ollama/libggml-cuda.so | grep RUNPATH

# For Nix flake build
readelf -d result/lib/ollama/libggml-cuda.so | grep RUNPATH
```

**Must NOT contain "stubs"!**

### Step 5: Test GPU Detection

**Flox:**
```bash
flox activate
OLLAMA_DEBUG=1 OLLAMA_MODELS=/tmp/test result-ollama-cuda/bin/ollama serve
```

**Nix Flake:**
```bash
OLLAMA_DEBUG=1 OLLAMA_MODELS=/tmp/test ./result/bin/ollama serve
```

**Expected output:**
```
count=1
NVIDIA GeForce RTX 5090
compute=12.0
total="31.8 GiB" available="30.6 GiB"
```

**Must NOT see:** `CUDA driver is a stub library`

### Step 6: Create Version Tag

If tests pass, create a git tag:

```bash
# Get version
VERSION=$(./result/bin/ollama --version 2>&1 | grep -o "0\.[0-9]*\.[0-9]*")

# Create annotated tag
git tag -a v${VERSION}-rtx5090 -m "Ollama ${VERSION} with CUDA support for RTX 5090

- Supports Blackwell architecture (compute 12.0)
- RUNPATH stub fix for non-NixOS systems
- Works with both Flox and Nix flakes
- GPU detection verified on RTX 5090"

# Push to GitHub (user must do this)
git push origin v${VERSION}-rtx5090
```

## Supported GPU Architectures

The build currently supports 9 CUDA architectures (see both Nix files):

```nix
cudaArches = [
  "sm_52"   # Maxwell - GTX 9xx
  "sm_61"   # Pascal - GTX 10xx
  "sm_75"   # Turing - RTX 20xx
  "sm_80"   # Ampere - RTX 30xx
  "sm_86"   # Ampere mobile
  "sm_89"   # Ada Lovelace - RTX 40xx
  "sm_90"   # Hopper - H100
  "sm_100"  # Blackwell datacenter
  "sm_120"  # Blackwell consumer - RTX 5090
];
```

If NVIDIA releases new architectures, add them to both `.flox/pkgs/ollama-cuda/default.nix` and `flake.nix`.

## Troubleshooting Build Issues

### autoPatchelfHook Re-adds Stubs

**Symptom:** RUNPATH contains stubs after build
**Cause:** Fix ran in wrong phase (e.g., `postFixup` instead of `preInstallCheck`)
**Solution:** Ensure fix is in `preInstallCheck` phase, which runs AFTER fixupPhase

### GPU Not Detected (count=0)

**Check:**
1. Stub paths in RUNPATH: `readelf -d .../libggml-cuda.so | grep RUNPATH`
2. Build log shows "SUCCESS: Stub paths removed"
3. NVIDIA driver installed: `nvidia-smi`
4. For Flox: LD_AUDIT set: `flox activate -- env | grep LD_AUDIT`

### Build Fails with CUDA Errors

**Check:**
1. NVIDIA driver supports compute capability (RTX 5090 needs driver 580.82.07+)
2. CUDA toolkit version matches driver
3. All cudaArches are valid for current CUDA version

## File Structure

**Files tracked in git:**
```
.
├── .flox/
│   ├── env/manifest.toml              # Flox environment definition
│   └── pkgs/ollama-cuda/
│       └── default.nix                # Flox: Custom Nix expression with RUNPATH fix
├── flake.nix                          # Nix flake with same RUNPATH fix
├── flake.lock                         # Flake lock file (reproducibility)
├── README.md                          # User documentation
├── FLAKE_USAGE.md                     # Nix flake user guide
└── .gitignore                         # Git ignore patterns
```

**Files NOT tracked** (local documentation/testing):
- `CLAUDE.md` - This maintenance guide (add to repo if desired)
- `FIX_SUMMARY.md` - Technical fix explanation
- `LD_AUDIT_INVESTIGATION_REPORT.md` - Full debugging investigation
- `FLOX.md`, `FLOX_OLLAMA_CUDA_TROUBLESHOOTING.md`, etc. - Session documentation
- `test_gpu.sh`, `build.nix`, `default.nix` - Temporary test files (in .gitignore)

## Key Technical Details

### Dynamic Linker Search Order
1. `LD_LIBRARY_PATH` environment variable
2. **RUNPATH** in ELF header (the problem!)
3. System config (`/etc/ld.so.conf`)
4. Default paths (`/lib`, `/usr/lib`)

### LD_AUDIT Mechanism (Flox Only)
- Intercepts ALL rtld calls including `dlopen()`
- Redirects Nix stub libraries to real system libraries
- Requires RUNPATH stub paths to be removed first
- Set via `LD_AUDIT=/path/to/floxlib.so`

### Build Phase Order
1. unpackPhase
2. patchPhase
3. configurePhase
4. buildPhase
5. installPhase
6. **fixupPhase** (autoPatchelfHook runs here)
7. **preInstallCheck** ← Our fix runs here!
8. installCheckPhase

## Testing Checklist

When updating to a new version, verify:

- [ ] Both builds complete without errors
- [ ] Build logs show "SUCCESS: Stub paths removed"
- [ ] RUNPATH contains NO "stubs" (readelf check)
- [ ] GPU detection shows `count=1`
- [ ] GPU name correct: "NVIDIA GeForce RTX 5090"
- [ ] Compute capability: 12.0
- [ ] No "stub library" error in logs
- [ ] `nix run` works (flake only)
- [ ] `nix develop` works (flake only)
- [ ] Version tag created and pushed

## Historical Context

### What Went Wrong Initially

1. **Theory 1:** "dlopen() bypasses LD_AUDIT" - **FALSE**
   - Expert corrected: LD_AUDIT intercepts ALL rtld calls
   - Verified with `LD_FLOXLIB_DEBUG=1`

2. **Theory 2:** "postFixup is the right phase" - **FALSE**
   - autoPatchelfHook runs AFTER postFixup
   - Solution: Use preInstallCheck (runs after fixupPhase)

3. **Theory 3:** "LD_AUDIT not working" - **FALSE**
   - LD_AUDIT works perfectly
   - Real problem: RUNPATH takes precedence over LD_AUDIT

### What Worked

- Using `preInstallCheck` phase to run fix AFTER autoPatchelfHook
- Filtering RUNPATH with `grep -v "stubs"`
- Verifying fix in build with explicit check
- Testing GPU detection with `OLLAMA_DEBUG=1`

See `LD_AUDIT_INVESTIGATION_REPORT.md` for complete investigation.

## Resources

- **Ollama GitHub:** https://github.com/ollama/ollama
- **Flox Docs:** https://flox.dev/docs
- **Nix Manual:** https://nixos.org/manual/nix/stable/
- **CUDA Architectures:** https://docs.nvidia.com/cuda/cuda-compiler-driver-nvcc/index.html#gpu-feature-list

## Quick Reference

```bash
# Update and rebuild
flox update && flox build ollama-cuda
nix flake update && nix build -L

# Verify fix
readelf -d result*/lib/ollama/libggml-cuda.so | grep RUNPATH | grep -q stubs && echo "FAIL: Stubs present" || echo "PASS: No stubs"

# Test GPU
OLLAMA_DEBUG=1 result*/bin/ollama serve 2>&1 | grep -E "(count=|stub|NVIDIA)"

# Tag and release
VERSION=$(result/bin/ollama --version 2>&1 | grep -o "[0-9]*\.[0-9]*\.[0-9]*")
git tag -a v${VERSION}-rtx5090 -m "Release message"
git push origin v${VERSION}-rtx5090
```
