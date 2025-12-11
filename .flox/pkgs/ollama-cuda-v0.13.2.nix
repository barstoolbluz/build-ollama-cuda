{ ollama-cuda, autoPatchelfHook, fetchFromGitHub, buildGoModule, lib }:

let
  version = "0.13.2";

  # Fixed-output derivation for Go dependencies
  src = fetchFromGitHub {
    owner = "ollama";
    repo = "ollama";
    rev = "v${version}";
    sha256 = "sha256-D3mPePAYzfGzeJfHfGky9XeVXXcCTJTdZv4LEs4/H5w=";
    fetchSubmodules = true;
  };

  # Vendor hash from nixpkgs PR #469312
  vendorHash = "sha256-NM0vtue0MFrAJCjmpYJ/rPEDWBxWCzBrWDb0MVOhY+Q=";

in
# Override the upstream ollama-cuda with our specific version
(ollama-cuda.override {
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
}).overrideAttrs (oldAttrs: {
  inherit version src;

  # Override the vendor hash for Go dependencies
  vendorHash = vendorHash;

  # Add autoPatchelfHook
  nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [ autoPatchelfHook ];

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
    else
      echo "WARNING: libggml-cuda.so not found"
    fi

    # Fix RUNPATH of other libggml libraries to find libggml-base.so
    for lib in $out/lib/ollama/libggml-*.so; do
      if [[ "$lib" == *"cuda"* ]]; then
        continue
      fi

      OLD_RUNPATH=$(patchelf --print-rpath "$lib")
      if [[ ! "$OLD_RUNPATH" == *"$out/lib/ollama"* ]]; then
        NEW_RUNPATH="$out/lib/ollama:$OLD_RUNPATH"
        patchelf --set-rpath "$NEW_RUNPATH" "$lib"
      fi
    done
  '';
})