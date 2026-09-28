{ inputs, pkgs }:

let
  binary =
    {
      "aarch64-linux" = inputs.agentgateway-linux-arm64;
      "x86_64-linux" = inputs.agentgateway-linux-amd64;
    }
    .${pkgs.stdenv.hostPlatform.system}
      or (throw "Unsupported AgentGateway platform: ${pkgs.stdenv.hostPlatform.system}");
in
pkgs.stdenvNoCC.mkDerivation {
  name = "agentgateway";

  src = binary;
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/agentgateway"
    runHook postInstall
  '';

  meta = {
    description = "Agent connectivity for any agent, framework, or environment";
    homepage = "https://agentgateway.dev";
    license = pkgs.lib.licenses.asl20;
    mainProgram = "agentgateway";
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
}
