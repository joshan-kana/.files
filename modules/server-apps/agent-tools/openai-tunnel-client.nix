{ inputs, pkgs }:

let
  inherit (pkgs) lib;
  assetPlatform =
    {
      "aarch64-linux" = "linux-arm64";
      "x86_64-linux" = "linux-amd64";
    }
    .${pkgs.stdenv.hostPlatform.system}
      or (throw "Unsupported tunnel-client platform: ${pkgs.stdenv.hostPlatform.system}");
  pattern = "([0-9a-f]{64})  tunnel-client-runtime-v([0-9]+\\.[0-9]+\\.[0-9]+)-${assetPlatform}\\.zip";
  matches = lib.filter (match: match != null) (
    map (line: builtins.match pattern line) (
      lib.splitString "\n" (builtins.readFile inputs.openai-tunnel)
    )
  );
  match =
    if builtins.length matches == 1 then
      builtins.head matches
    else
      throw "Missing tunnel-client checksum for ${assetPlatform}";
  checksum = builtins.elemAt match 0;
  version = builtins.elemAt match 1;
  assetName = "tunnel-client-runtime-v${version}-${assetPlatform}.zip";
  hash = builtins.convertHash {
    hash = checksum;
    hashAlgo = "sha256";
    toHashFormat = "sri";
  };
in
pkgs.runCommand "tunnel-client-${version}"
  {
    nativeBuildInputs = [ pkgs.unzip ];
  }
  ''
    mkdir -p "$out/bin"
    unzip -j ${
      pkgs.fetchurl {
        url = "https://github.com/openai/tunnel-client/releases/download/v${version}/${assetName}";
        inherit hash;
      }
    } tunnel-client-runtime -d "$out/bin"
    mv "$out/bin/tunnel-client-runtime" "$out/bin/tunnel-client"
    chmod +x "$out/bin/tunnel-client"
  ''
