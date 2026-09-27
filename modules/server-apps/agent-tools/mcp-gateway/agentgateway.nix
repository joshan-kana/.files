{ inputs, pkgs }:

let
  inherit (pkgs) lib;
  release = builtins.fromJSON (builtins.readFile inputs.agentgateway-release);
  version = lib.removePrefix "v" release.tag_name;
  assetPlatform =
    {
      "aarch64-linux" = "linux-arm64";
      "x86_64-linux" = "linux-amd64";
    }
    .${pkgs.stdenv.hostPlatform.system}
      or (throw "Unsupported AgentGateway platform: ${pkgs.stdenv.hostPlatform.system}");
  assetName = "agentgateway-${assetPlatform}";
  asset = lib.findFirst (
    asset: asset.name == assetName
  ) (throw "Missing AgentGateway release asset ${assetName}") release.assets;
  hash = builtins.convertHash {
    hash = lib.removePrefix "sha256:" asset.digest;
    hashAlgo = "sha256";
    toHashFormat = "sri";
  };
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "agentgateway";
  inherit version;

  src = pkgs.fetchurl {
    url = asset.browser_download_url;
    inherit hash;
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/agentgateway"
    runHook postInstall
  '';

  meta = {
    description = "Agent connectivity for any agent, framework, or environment";
    homepage = "https://agentgateway.dev";
    license = lib.licenses.asl20;
    mainProgram = "agentgateway";
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
}
