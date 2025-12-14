# Version Branch Notes

## Created Branches

### v0.13.0
- Source hash: `sha256-VhBPYf/beWkeFCdBTC2UpxqQUgEX8TCkbiWBPg8gDb4=`
- Vendor hash: Needs to be determined by building (placeholder from v0.13.1)

### v0.12.11
- Source hash: `sha256-AxOhAqW5RgbnQ5N2F5CiUZ1D7W9GXqr9KxtHE+j+lVk=`
- Vendor hash: Needs to be determined by building

### v0.12.9
- Source hash: `sha256-AhjrbJa9f6bJ3vzLxJmfj9Lkgg1ijRcElXRy2YG4fgs=`
- Vendor hash: Needs to be determined by building

## How to Get Correct Vendor Hashes

For each version branch, to get the correct vendor hash:

1. Try to build: `flox build ollama-cuda`
2. The build will fail with a hash mismatch error showing the expected hash
3. Update `.flox/pkgs/ollama-cuda.nix` with the correct vendor hash
4. Rebuild to verify

Or check nixpkgs history/PRs for when that version was added to find the vendor hash.