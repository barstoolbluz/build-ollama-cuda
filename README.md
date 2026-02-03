# Ollama CUDA

Custom Ollama build with CUDA support for NVIDIA GPUs (GTX 9xx through RTX 50xx) on Linux systems.

## Problem This Solves

1. **RUNPATH stub issue (non-NixOS):** The upstream nixpkgs `ollama-cuda` package has stub library paths in RUNPATH that prevent GPU detection on non-NixOS systems. This build removes those stub paths.

2. **Extended CUDA architectures:** Adds support for newer GPU architectures (including sm_120 for RTX 5090) not yet in upstream nixpkgs.

## Branches

| Branch | Description |
|--------|-------------|
| `latest` | Bleeding edge - tracks upstream [Ollama GitHub releases](https://github.com/ollama/ollama/releases) |
| `main` | Stable - most recently deprecated version from `latest` |
| `v0.x.x` | Archived versions (e.g., `v0.14.3`, `v0.14.1`) |

## Quick Start (Flox)

```bash
# Clone this repo
git clone https://github.com/barstoolbluz/ollama-cuda.git
cd ollama-cuda

# For stable version (main branch - default)
flox build ollama-cuda

# For bleeding edge
git checkout latest
flox build ollama-cuda

# For specific version (use `git branch -a` to list available versions)
git checkout v0.14.3
flox build ollama-cuda

# Run the built binary
./result-ollama-cuda/bin/ollama serve
```

## Quick Start (Nix Flake)

```bash
# Clone this repo
git clone https://github.com/barstoolbluz/ollama-cuda.git
cd ollama-cuda

# Build
nix build --extra-experimental-features 'nix-command flakes'

# Run the built binary
./result/bin/ollama serve

# Or run directly without building first
nix run --extra-experimental-features 'nix-command flakes' .

# Or install to your profile
nix profile install --extra-experimental-features 'nix-command flakes' .
```

## Features

- CUDA support for RTX 5090 (sm_120 / compute 12.0)
- All 9 GPU architectures supported (Maxwell through Blackwell)
- Automatic RUNPATH fixing to remove stub libraries
- Works on any Linux distribution (NixOS and non-NixOS)

## Supported GPU Architectures

| Architecture | Compute | GPUs |
|--------------|---------|------|
| sm_52 | Maxwell | GTX 9xx |
| sm_61 | Pascal | GTX 10xx |
| sm_75 | Turing | RTX 20xx |
| sm_80 | Ampere | RTX 30xx |
| sm_86 | Ampere | RTX 30xx mobile |
| sm_89 | Ada Lovelace | RTX 40xx |
| sm_90 | Hopper | H100 |
| sm_100 | Blackwell | Datacenter |
| sm_120 | Blackwell | RTX 50xx |

## How It Works

The Nix expressions (`.flox/pkgs/ollama-cuda.nix` for Flox, `flake.nix` for pure Nix):

1. Fetch the specified Ollama version directly from GitHub
2. Override upstream `ollama-cuda` with extended CUDA architectures
3. Use `preInstallCheck` phase to run AFTER `autoPatchelfHook`
4. Remove stub library paths from `libggml-cuda.so` RUNPATH
5. Allow proper GPU detection on non-NixOS systems

## Publishing to FloxHub

```bash
# Publish to your personal catalog
flox publish ollama-cuda

# Publish to an organization
flox publish -o myorg ollama-cuda

# Then install from anywhere
flox install <username>/ollama-cuda
```

## System Requirements

- **OS:** Linux (any distribution)
- **GPU:** NVIDIA CUDA-capable GPU
- **Driver:** NVIDIA driver appropriate for your GPU (580.82.07+ for RTX 5090)
- **Tools:** [Flox](https://flox.dev) OR Nix with flakes enabled

## File Structure

```
.
├── .flox/
│   ├── env/manifest.toml       # Flox environment definition
│   └── pkgs/
│       └── ollama-cuda.nix     # Nix expression (for Flox)
├── flake.nix                   # Nix flake (for pure Nix/NixOS)
├── flake.lock                  # Flake lock file
└── README.md
```

## Troubleshooting

### GPU Not Detected

```bash
# Check GPU is visible
nvidia-smi

# Check LD_AUDIT is set (Flox only, within flox activate)
flox activate -- env | grep LD_AUDIT

# Run with debug output
# Flox build:
OLLAMA_DEBUG=1 ./result-ollama-cuda/bin/ollama serve
# Nix flake build:
OLLAMA_DEBUG=1 ./result/bin/ollama serve
```

### Verify RUNPATH Fix

```bash
# Should NOT contain "stubs"
# Flox build:
readelf -d result-ollama-cuda/lib/ollama/libggml-cuda.so | grep RUNPATH
# Nix flake build:
readelf -d result/lib/ollama/libggml-cuda.so | grep RUNPATH
```

### Build Issues

```bash
# Clean and rebuild (Flox)
rm -rf result-ollama-cuda
flox build ollama-cuda

# Clean and rebuild (Nix flake)
rm -rf result
nix build --extra-experimental-features 'nix-command flakes'
```

## License

This custom build configuration is provided as-is. Ollama itself is licensed under MIT.
