{ pkgs }:

let
  version = "0.0.11";
  platform =
    {
      "aarch64-linux" = {
        asset = "linux-arm64";
        hash = "sha256-2LukeypyN5mjcrC4fX5NaTBAk9OiiDcjcxX+VAbZfnc=";
      };
      "x86_64-linux" = {
        asset = "linux-amd64";
        hash = "sha256-Ka3+XBOZ37n9qTg/IwwyQ1WRL1DcNuLkFrHxMiMXs8Q=";
      };
    }
    .${pkgs.stdenv.hostPlatform.system}
      or (throw "Unsupported tunnel-client platform: ${pkgs.stdenv.hostPlatform.system}");
in
pkgs.runCommand "tunnel-client-${version}"
  {
    nativeBuildInputs = [ pkgs.unzip ];
  }
  ''
    mkdir -p "$out/bin"
    unzip -j ${
      pkgs.fetchurl {
        url = "https://persistent.oaistatic.com/tunnel-client/v${version}/tunnel-client-v${version}-${platform.asset}.zip";
        inherit (platform) hash;
      }
    } tunnel-client -d "$out/bin"
    chmod +x "$out/bin/tunnel-client"
  ''
