# Ollama CUDA (Flox Build)

Custom Ollama build with CUDA support for NVIDIA GPUs (GTX 9xx through RTX 50xx) on non-NixOS systems.

## Problem This Solves

The upstream nixpkgs `ollama-cuda` package has stub library paths in RUNPATH that prevent GPU detection on non-NixOS systems. This custom build removes those stub paths, allowing Flox's LD_AUDIT mechanism to properly redirect to system NVIDIA drivers.

## Branches

| Branch | Description |
|--------|-------------|
| `latest` | Bleeding edge - tracks upstream [Ollama GitHub releases](https://github.com/ollama/ollama/releases) |
| `main` | Stable - most recently deprecated version from `latest` |
| `v0.x.x` | Archived versions (e.g., `v0.14.3`, `v0.14.1`) |

## Quick Start

```bash
# Clone this repo
git clone https://github.com/barstoolbluz/ollama-cuda.git
cd ollama-cuda

# For stable version (main branch - default)
flox build ollama-cuda

# For bleeding edge
git checkout latest
flox build ollama-cuda

# For specific version
git checkout v0.14.3
flox build ollama-cuda

# Run the built binary
./result-ollama-cuda/bin/ollama serve
```

## Publishing to FloxHub

```bash
# Publish to your personal catalog
flox publish ollama-cuda

# Publish to an organization
flox publish -o myorg ollama-cuda

# Then install from anywhere
flox install <username>/ollama-cuda
```

## Features

- CUDA support for RTX 5090 (sm_120 / compute 12.0)
- All 9 GPU architectures supported (Maxwell through Blackwell)
- Automatic RUNPATH fixing to remove stub libraries
- Works on non-NixOS systems (Debian, Ubuntu, etc.)
- Flox LD_AUDIT compatible

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

The Nix expression in `.flox/pkgs/ollama-cuda.nix`:

1. Fetches the specified Ollama version directly from GitHub
2. Overrides upstream `ollama-cuda` with extended CUDA architectures
3. Uses `preInstallCheck` phase to run AFTER `autoPatchelfHook`
4. Removes stub library paths from `libggml-cuda.so` RUNPATH
5. Allows Flox's LD_AUDIT to redirect to real system drivers

## System Requirements

- **OS:** Linux (non-NixOS: Debian, Ubuntu, etc.)
- **GPU:** NVIDIA CUDA-capable GPU
- **Driver:** NVIDIA driver appropriate for your GPU (580.82.07+ for RTX 5090)
- **Tools:** [Flox](https://flox.dev)

## File Structure

```
.
├── .flox/
│   ├── env/manifest.toml       # Flox environment definition
│   └── pkgs/
│       └── ollama-cuda.nix     # Nix expression with RUNPATH fix
├── flake.nix                   # Nix flake (alternative build method)
├── flake.lock                  # Flake lock file
└── README.md
```

## Troubleshooting

### GPU Not Detected

```bash
# Check GPU is visible
nvidia-smi

# Check LD_AUDIT is set (within flox activate)
flox activate -- env | grep LD_AUDIT

# Run with debug output
OLLAMA_DEBUG=1 ./result-ollama-cuda/bin/ollama serve
```

### Verify RUNPATH Fix

```bash
# Should NOT contain "stubs"
readelf -d result-ollama-cuda/lib/ollama/libggml-cuda.so | grep RUNPATH
```

### Build Issues

```bash
# Clean and rebuild
rm -rf result-ollama-cuda
flox build ollama-cuda
```

## License

This custom build configuration is provided as-is. Ollama itself is licensed under MIT.
