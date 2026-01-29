{ ollama-cuda, autoPatchelfHook, fetchFromGitHub }:

# Override the upstream ollama-cuda to:
# 1. Use latest stable Ollama v0.14.3
# 2. Build for all 9 GPU architectures including RTX 5090 (sm_120)
# 3. Fix RUNPATH to remove stub libraries and allow Flox LD_AUDIT to work
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
  # Override to v0.14.3 (latest stable release)
  version = "0.14.3";
  src = fetchFromGitHub {
    owner = "ollama";
    repo = "ollama";
    rev = "v0.14.3";
    sha256 = "sha256-SVzJDuy5qXaqxE4HqiqVhoyGLTOt57370q8r3YV18Og=";
    fetchSubmodules = true;
  };
  vendorHash = "sha256-WdHAjCD20eLj0d9v1K6VYP8vJ+IZ8BEZ3CciYLLMtxc=";

  # Add autoPatchelfHook
  nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [ autoPatchelfHook ];

  # postFixup runs during fixupPhase but autoPatchelfHook runs last
  # So we append to fixupOutputHooks to run AFTER autoPatchelfHook
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
