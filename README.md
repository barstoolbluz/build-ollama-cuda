# Ollama CUDA for RTX 5090 (Flox Build)

Custom Ollama build with CUDA support for NVIDIA RTX 5090 (Blackwell architecture, compute capability 12.0) on non-NixOS systems using Flox.

## Problem This Solves

The upstream nixpkgs `ollama-cuda` package has stub library paths in RUNPATH that prevent GPU detection on non-NixOS systems. This custom build removes those stub paths, allowing Flox's LD_AUDIT mechanism to properly redirect to system NVIDIA drivers.

## Quick Start

### Using Flox (Recommended for non-NixOS)

```bash
# Clone this repo
git clone https://github.com/YOUR_USERNAME/ollama-cuda.git
cd ollama-cuda

# Activate Flox environment
flox activate

# Build ollama-cuda
flox build ollama-cuda

# Install
flox install ollama-cuda

# Run
ollama serve
```

### Using Nix Flake

```bash
# Build and run directly from GitHub
nix run github:YOUR_USERNAME/ollama-cuda

# Or install to profile
nix profile install github:YOUR_USERNAME/ollama-cuda
ollama serve
```

See **[FLAKE_USAGE.md](FLAKE_USAGE.md)** for detailed flake documentation.

## Features

- ✅ CUDA support for RTX 5090 (sm_120 / compute 12.0)
- ✅ All 9 GPU architectures supported (Maxwell to Blackwell)
- ✅ Automatic RUNPATH fixing to remove stub libraries
- ✅ Works on non-NixOS systems (Debian, Ubuntu, etc.)
- ✅ Flox LD_AUDIT compatible

## How It Works

The custom Nix expression in `.flox/pkgs/ollama-cuda/default.nix`:

1. Overrides upstream `ollama-cuda` with extended CUDA architectures
2. Uses `preInstallCheck` phase to run AFTER `autoPatchelfHook`
3. Removes stub library paths from libggml-cuda.so RUNPATH
4. Allows Flox's LD_AUDIT to redirect to real system drivers

See `FIX_SUMMARY.md` for technical details.

## Tracking Upstream Ollama Releases

### Option 1: Manual Updates (Recommended)

When a new Ollama version is released:

```bash
# Check upstream version
nix-env -qa ollama-cuda

# Update flox catalog (pulls latest nixpkgs)
flox update

# Rebuild with new version
flox build ollama-cuda

# Test
result-ollama-cuda/bin/ollama --version

# Install if good
flox install ollama-cuda
```

### Option 2: Automated GitHub Actions

Add `.github/workflows/update-ollama.yml`:

```yaml
name: Check for Ollama Updates
on:
  schedule:
    - cron: '0 0 * * *'  # Daily at midnight
  workflow_dispatch:

jobs:
  check-update:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install Flox
        run: |
          curl -fsSL https://downloads.flox.dev/by-env/stable/install.sh | bash
      - name: Check for updates
        run: |
          # Check upstream version vs current
          # Create PR if newer version available
```

### Option 3: Dependabot-style (Manual Setup)

Create `renovate.json` for automatic PR creation when nixpkgs updates.

## System Requirements

- **OS:** Non-NixOS Linux (Debian, Ubuntu, etc.)
- **GPU:** NVIDIA RTX 5090 or other CUDA-capable GPU
- **Driver:** NVIDIA driver 580.82.07+ (for RTX 5090)
- **Tools:** Flox environment manager

## File Structure

```
.
├── .flox/
│   ├── env/manifest.toml          # Flox environment definition
│   └── pkgs/ollama-cuda/
│       └── default.nix            # Custom Nix expression with RUNPATH fix
├── README.md                       # This file
├── FIX_SUMMARY.md                 # Technical fix explanation
└── LD_AUDIT_INVESTIGATION_REPORT.md  # Detailed investigation
```

## Troubleshooting

### GPU Not Detected

```bash
# Check GPU is visible
nvidia-smi

# Check LD_AUDIT is set
flox activate -- env | grep LD_AUDIT

# Run with debug
OLLAMA_DEBUG=1 ollama serve
```

### Build Issues

```bash
# Clean build
rm -f result-ollama-cuda*
flox build ollama-cuda

# Check RUNPATH
readelf -d result-ollama-cuda/lib/ollama/libggml-cuda.so | grep RUNPATH
# Should NOT contain "stubs"
```

## Contributing

1. Fork this repo
2. Make your changes
3. Test with `flox build ollama-cuda`
4. Submit PR

## Credits

- **Ollama:** https://github.com/ollama/ollama
- **Flox:** https://flox.dev
- **Investigation:** See `LD_AUDIT_INVESTIGATION_REPORT.md` for full debugging story

## License

This custom build configuration is provided as-is. Ollama itself is licensed under MIT.
