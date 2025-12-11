{ buildGoModule, fetchFromGitHub }:
buildGoModule rec {
  pname = "ollama-vendor-test";
  version = "0.13.2";
  src = fetchFromGitHub {
    owner = "ollama";
    repo = "ollama";
    rev = "v";
    sha256 = "sha256-D3mPePAYzfGzeJfHfGky9XeVXXcCTJTdZv4LEs4/H5w=";
    fetchSubmodules = true;
  };
  vendorHash = null; # This will cause an error showing the expected hash
}
