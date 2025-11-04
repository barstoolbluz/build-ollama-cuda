# Using the Nix Flake

This repository provides a Nix flake that builds Ollama with CUDA support for RTX 5090, including the RUNPATH stub fix.

## Prerequisites

Enable flakes in your Nix configuration:

```bash
# Add to ~/.config/nix/nix.conf or /etc/nix/nix.conf
experimental-features = nix-command flakes
```

Or use `--extra-experimental-features` with each command.

## Quick Usage

### Build and Run

```bash
# Build the package
nix build

# Run directly
./result/bin/ollama serve

# Or run without building
nix run
```

### Install to Profile

```bash
# Install to your user profile
nix profile install .

# Now ollama is in your PATH
ollama serve
```

### Development Shell

```bash
# Enter development shell with ollama available
nix develop

# Inside the shell:
ollama --version
ollama serve
```

## Advanced Usage

### Build from GitHub (without cloning)

```bash
# Build directly from GitHub
nix build github:YOUR_USERNAME/ollama-cuda

# Run directly from GitHub
nix run github:YOUR_USERNAME/ollama-cuda

# Install from GitHub
nix profile install github:YOUR_USERNAME/ollama-cuda
```

### Pin a Specific Version

```bash
# Build specific commit
nix build github:YOUR_USERNAME/ollama-cuda/COMMIT_HASH

# Build specific tag
nix build github:YOUR_USERNAME/ollama-cuda/v0.12.6-rtx5090
```

### Use in Another Flake

Add to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    ollama-cuda.url = "github:YOUR_USERNAME/ollama-cuda";
  };

  outputs = { self, nixpkgs, ollama-cuda }: {
    # Use in your system configuration
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        {
          environment.systemPackages = [
            ollama-cuda.packages.x86_64-linux.default
          ];
        }
      ];
    };
  };
}
```

### Use in NixOS Configuration

In your `/etc/nixos/configuration.nix`:

```nix
{ config, pkgs, ... }:

{
  # Import the flake
  nixpkgs.overlays = [
    (final: prev: {
      ollama-cuda-rtx5090 = (builtins.getFlake "github:YOUR_USERNAME/ollama-cuda").packages.${prev.system}.default;
    })
  ];

  # Install
  environment.systemPackages = with pkgs; [
    ollama-cuda-rtx5090
  ];

  # Or use as a service
  systemd.services.ollama = {
    description = "Ollama LLM Service";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.ollama-cuda-rtx5090}/bin/ollama serve";
      Restart = "always";
      User = "ollama";
      Group = "ollama";
      Environment = "OLLAMA_HOST=0.0.0.0:11434";
    };
  };

  # Create user
  users.users.ollama = {
    isSystemUser = true;
    group = "ollama";
  };
  users.groups.ollama = {};
}
```

## Flake Outputs

This flake provides:

- **`packages.default`** - The main ollama-cuda package
- **`packages.ollama-cuda`** - Alias for the main package
- **`apps.default`** - Run ollama directly
- **`devShells.default`** - Development environment

## Updating

### Update to Latest nixpkgs

```bash
# Update flake.lock
nix flake update

# Rebuild
nix build

# Test
./result/bin/ollama --version
```

### Update Specific Input

```bash
# Update only nixpkgs
nix flake lock --update-input nixpkgs

# Update only flake-utils
nix flake lock --update-input flake-utils
```

## Verifying the Fix

After building, verify the RUNPATH fix was applied:

```bash
# Check that stub paths are removed
nix build
readelf -d result/lib/ollama/libggml-cuda.so | grep RUNPATH
# Should NOT contain "stubs"

# Check build log
nix build -L 2>&1 | grep "SUCCESS: Stub paths removed"

# Test GPU detection
OLLAMA_DEBUG=1 ./result/bin/ollama serve
# Should show: count=1 and "NVIDIA GeForce RTX 5090"
```

## Troubleshooting

### Build Fails

```bash
# Clean and rebuild
nix build --rebuild

# Build with verbose output
nix build -L
```

### GPU Not Detected

```bash
# Check NVIDIA driver
nvidia-smi

# Run with debug
OLLAMA_DEBUG=1 ./result/bin/ollama serve

# Check for stub error
# Should NOT see: "CUDA driver is a stub library"
```

### Cache Issues

```bash
# Clear nix store for this package
nix-collect-garbage

# Rebuild from scratch
rm -rf result
nix build --rebuild
```

## Binary Cache (Optional)

If you want to set up a binary cache for faster builds:

### Push to Cachix

```bash
# Install cachix
nix-env -iA cachix -f https://cachix.org/api/v1/install

# Create cache (one time)
cachix create YOUR-CACHE-NAME

# Configure to use cache
cachix use YOUR-CACHE-NAME

# Push built derivations
nix build
cachix push YOUR-CACHE-NAME ./result
```

### Share Cache URL

Users can then use your cache:

```bash
cachix use YOUR-CACHE-NAME
nix build github:YOUR_USERNAME/ollama-cuda
```

## Continuous Integration

Example GitHub Actions workflow:

```yaml
name: Build Ollama CUDA

on:
  push:
    branches: [ master ]
  pull_request:
    branches: [ master ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: cachix/install-nix-action@v24
        with:
          extra_nix_config: |
            experimental-features = nix-command flakes

      - name: Build
        run: nix build -L

      - name: Verify RUNPATH fix
        run: |
          readelf -d result/lib/ollama/libggml-cuda.so | grep RUNPATH
          ! readelf -d result/lib/ollama/libggml-cuda.so | grep RUNPATH | grep -q stubs

      - name: Check version
        run: ./result/bin/ollama --version
```

## Comparison: Flake vs Flox

| Feature | Nix Flake | Flox |
|---------|-----------|------|
| Lock file | `flake.lock` | `.flox/env.lock` |
| Build command | `nix build` | `flox build` |
| Activation | N/A | `flox activate` |
| LD_AUDIT | No (pure Nix) | Yes (for non-NixOS) |
| Best for | NixOS, reproducible builds | Non-NixOS development |

**Use the flake when:**
- Building on NixOS
- Need reproducible builds with lock file
- Sharing via Nix binary cache
- Using in NixOS configuration

**Use Flox when:**
- Developing on non-NixOS (Debian, Ubuntu, etc.)
- Need LD_AUDIT for system library redirection
- Want quick activation without building

Both use the same RUNPATH fix logic!
