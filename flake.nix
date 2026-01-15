{
  description = "Ollama with CUDA support for RTX 5090 (Blackwell) - RUNPATH stub fix for non-NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            cudaSupport = true;
          };
        };

        # Custom ollama-cuda with RUNPATH fix
        ollama-cuda-fixed = pkgs.ollama-cuda.override {
          acceleration = "cuda";
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
        };

        # Apply RUNPATH fix and update to v0.14.1 using overrideAttrs
        ollama-cuda-rtx5090 = ollama-cuda-fixed.overrideAttrs (oldAttrs: {
          # Override to v0.14.1 (latest stable release)
          version = "0.14.1";
          src = pkgs.fetchFromGitHub {
            owner = "ollama";
            repo = "ollama";
            rev = "v0.14.1";
            sha256 = "sha256-r9Qwa1bAzLlr50mB+RLkRfuCFe6FUXtR9irqvU7PAvA=";
            fetchSubmodules = true;
          };
          vendorHash = "sha256-WdHAjCD20eLj0d9v1K6VYP8vJ+IZ8BEZ3CciYLLMtxc=";

          nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [ pkgs.autoPatchelfHook ];

          # postFixup runs during fixupPhase but autoPatchelfHook runs last
          postFixup = (oldAttrs.postFixup or "") + ''
            # Hide the non-functional app
            mv "$out/bin/app" "$out/bin/.ollama-app" 2>/dev/null || true
          '';

          # This runs AFTER all fixup hooks including autoPatchelfHook
          preInstallCheck = ''
            echo "=== Removing stub paths from libggml-cuda.so RUNPATH ==="

            if [ -f "$out/lib/ollama/libggml-cuda.so" ]; then
              echo "Processing libggml-cuda.so..."
              OLD_RUNPATH=$(${pkgs.patchelf}/bin/patchelf --print-rpath "$out/lib/ollama/libggml-cuda.so")
              echo "Original RUNPATH: $OLD_RUNPATH"

              # Filter out stub paths
              NEW_RUNPATH=$(echo "$OLD_RUNPATH" | tr ':' '\n' | grep -v "stubs" | tr '\n' ':' | sed 's/:$//')

              echo "New RUNPATH (stubs removed): $NEW_RUNPATH"
              ${pkgs.patchelf}/bin/patchelf --set-rpath "$NEW_RUNPATH" "$out/lib/ollama/libggml-cuda.so"

              # Verify the change
              FINAL_RUNPATH=$(${pkgs.patchelf}/bin/patchelf --print-rpath "$out/lib/ollama/libggml-cuda.so")
              echo "Final RUNPATH: $FINAL_RUNPATH"

              if echo "$FINAL_RUNPATH" | grep -q "stubs"; then
                echo "ERROR: Stub paths still present!"
                exit 1
              else
                echo "SUCCESS: Stub paths removed"
              fi
            else
              echo "WARNING: libggml-cuda.so not found"
            fi

            # Fix RUNPATH of other libggml libraries to find libggml-base.so
            for lib in $out/lib/ollama/libggml-*.so; do
              if [[ "$lib" == *"cuda"* ]]; then
                continue
              fi

              OLD_RUNPATH=$(${pkgs.patchelf}/bin/patchelf --print-rpath "$lib")
              if [[ ! "$OLD_RUNPATH" == *"$out/lib/ollama"* ]]; then
                NEW_RUNPATH="$out/lib/ollama:$OLD_RUNPATH"
                ${pkgs.patchelf}/bin/patchelf --set-rpath "$NEW_RUNPATH" "$lib"
              fi
            done
          '';
        });

      in
      {
        # Main package
        packages.default = ollama-cuda-rtx5090;
        packages.ollama-cuda = ollama-cuda-rtx5090;

        # App for easy running
        apps.default = {
          type = "app";
          program = "${ollama-cuda-rtx5090}/bin/ollama";
        };

        # Development shell
        devShells.default = pkgs.mkShell {
          buildInputs = [
            ollama-cuda-rtx5090
            pkgs.patchelf
            pkgs.binutils
          ];

          shellHook = ''
            echo "Ollama CUDA RTX 5090 development environment"
            echo "Ollama version: $(ollama --version 2>/dev/null || echo 'not in PATH')"
            echo ""
            echo "Available commands:"
            echo "  ollama serve     - Start Ollama server"
            echo "  ollama --version - Check version"
            echo ""
            echo "Debug GPU detection:"
            echo "  OLLAMA_DEBUG=1 ollama serve"
          '';
        };
      }
    );
}
