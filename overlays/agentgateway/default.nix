let
  package =
    {
      stdenvNoCC,
      lib,
      fetchurl,
      python3,
    }:
    let
      version = "1.7.0";
      hashes = {
        aarch64-darwin = "sha256-NL/JYdDkWdD4kQMQDmFzDUtdjiFRyFHTPNA0oSbrK/4=";
        aarch64-linux = "sha256-hXJKFdyfUXn7bi/YWwui1P6lbdKJq7i/j++tw76ouJ4=";
        x86_64-linux = "sha256-Gy/AGi3inKETu7Yli1yuex6zxyQHHAnWh6RJEy8vQvg=";
      };
      system = stdenvNoCC.hostPlatform.system;
      asset =
        {
          aarch64-darwin = "darwin-arm64";
          aarch64-linux = "linux-arm64";
          x86_64-linux = "linux-amd64";
        }
        .${system} or (throw "Unsupported AgentGateway platform: ${system}");
    in
    stdenvNoCC.mkDerivation {
      pname = "agentgateway";
      inherit version;
      src = fetchurl {
        url = "https://github.com/agentgateway/agentgateway/releases/download/v${version}/agentgateway-${asset}";
        hash = hashes.${system};
      };
      dontUnpack = true;
      passthru.updateScript = [
        "${python3}/bin/python3"
        "${../../scripts/update-binary-release.py}"
        "agentgateway"
      ];
      installPhase = ''
        runHook preInstall
        mkdir -p "$out/bin"
        install -m755 "$src" "$out/bin/agentgateway"
        runHook postInstall
      '';
      meta = {
        description = "Agent connectivity for any agent, framework, or environment";
        homepage = "https://agentgateway.dev";
        license = lib.licenses.asl20;
        mainProgram = "agentgateway";
        platforms = [
          "aarch64-darwin"
          "aarch64-linux"
          "x86_64-linux"
        ];
      };
    };
in
_: {
  dotfiles.updatePolicy."agentgateway" = "auto";
  nixpkgs.overlays = [
    (
      final: prev:
      prev.lib.optionalAttrs
        (builtins.elem prev.stdenv.hostPlatform.system [
          "aarch64-darwin"
          "aarch64-linux"
          "x86_64-linux"
        ])
        {
          agentgateway = final.callPackage package { };
        }
    )
  ];
}
