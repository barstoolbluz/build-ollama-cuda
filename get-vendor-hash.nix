{ pkgs ? import <nixpkgs> {} }:

pkgs.buildGoModule rec {
  pname = "ollama-vendor-test";
  version = "0.13.2";

  src = pkgs.fetchFromGitHub {
    owner = "ollama";
    repo = "ollama";
    rev = "v${version}";
    sha256 = "sha256-D3mPePAYzfGzeJfHfGky9XeVXXcCTJTdZv4LEs4/H5w=";
    fetchSubmodules = true;
  };

  # Set to lib.fakeSha256 to get the real hash
  vendorHash = pkgs.lib.fakeSha256;

  # Minimal build to just get vendor hash
  buildPhase = "true";
  installPhase = "mkdir -p $out";
}