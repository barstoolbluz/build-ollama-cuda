#!/usr/bin/env bash
set -euo pipefail

# Check for new Ollama releases, prefetch source hash, and update .nix + flake.nix files.
# Creates a PR with the version bump. vendorHash is set to a placeholder — the user
# must build locally (CUDA required) to get the correct hash.
#
# Usage: update-ollama-version.sh
# Environment: GH_TOKEN (required)

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NIX_FILE="$REPO_ROOT/.flox/pkgs/ollama-cuda.nix"
FLAKE_FILE="$REPO_ROOT/flake.nix"

output_var="${GITHUB_OUTPUT:-/dev/stdout}"

# Get current version from the .nix file
current_version=$(grep -oP 'version = "\K[^"]+' "$NIX_FILE" | head -1)
echo "Current version: $current_version"

# Get latest release from GitHub
latest_tag=$(gh api repos/ollama/ollama/releases/latest --jq '.tag_name')
latest_version="${latest_tag#v}"
echo "Latest version:  $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date."
  echo "updated=false" >>"$output_var"
  exit 0
fi

echo "Update available: $current_version -> $latest_version"

# Prefetch source hash
echo "Prefetching source for v${latest_version}..."
src_hash=$(nix --extra-experimental-features nix-command hash convert --hash-algo sha256 --to sri \
  "$(nix-prefetch-url --unpack "https://github.com/ollama/ollama/archive/refs/tags/v${latest_version}.tar.gz" 2>/dev/null)")
echo "Source hash: $src_hash"

# Update both files
for file in "$NIX_FILE" "$FLAKE_FILE"; do
  echo "Updating $(basename "$file")..."

  # Update version (first occurrence only)
  sed -i "0,/version = \"[^\"]*\"/{s/version = \"[^\"]*\"/version = \"$latest_version\"/}" "$file"

  # Update rev
  sed -i "s|rev = \"v[^\"]*\"|rev = \"v$latest_version\"|" "$file"

  # Update source hash (the sha256 inside fetchFromGitHub block)
  sed -i "/fetchFromGitHub/,/};/{
    s|sha256 = \"sha256-[^\"]*\"|sha256 = \"$src_hash\"|
  }" "$file"

  # Set vendorHash to placeholder — must be fixed by local build
  sed -i "s|vendorHash = \"sha256-[^\"]*\"|vendorHash = \"sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\"|" "$file"
done

# Also update the existing update-ollama.sh script if it has a hardcoded version
if [ -f "$REPO_ROOT/update-ollama.sh" ]; then
  echo "update-ollama.sh left as-is (queries GitHub dynamically)"
fi

echo
echo "=== Updated to v${latest_version} ==="
echo "NOTE: vendorHash is a PLACEHOLDER. You must build locally to get the correct hash:"
echo "  flox build ollama-cuda 2>&1 | grep 'got:'"
echo "  # Then update vendorHash in both files"

echo "updated=true" >>"$output_var"
echo "current_version=$current_version" >>"$output_var"
echo "new_version=$latest_version" >>"$output_var"
