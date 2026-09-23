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
  assets = lib.filter (asset: asset.name == assetName) release.assets;
  asset =
    if builtins.length assets == 1 then
      builtins.head assets
    else
      throw "Missing AgentGateway release asset ${assetName}";
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
    url = "https://github.com/agentgateway/agentgateway/releases/download/v${version}/${assetName}";
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
