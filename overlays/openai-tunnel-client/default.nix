_: {
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
          openai-tunnel-client = final.callPackage (
            {
              stdenvNoCC,
              fetchurl,
              unzip,
              python3,
            }:
            let
              version = "0.0.19";
              hashes = {
                aarch64-darwin = "sha256-IldgWEVjoa1u5yWFvAAbrjSnFB1zJGoRfO7ShAkFkMw=";
                aarch64-linux = "sha256-7dAWZ9Rrzr+ojdF9kr21YVhnaKfeNBC4s8g5e1J/1uk=";
                x86_64-linux = "sha256-pDvq5vCFBaG2dRBX0CeXuqcKiO9/nrXf0DpVtrKRFq0=";
              };
              system = stdenvNoCC.hostPlatform.system;
              asset =
                {
                  aarch64-darwin = "darwin-arm64";
                  aarch64-linux = "linux-arm64";
                  x86_64-linux = "linux-amd64";
                }
                .${system} or (throw "Unsupported tunnel-client platform: ${system}");
            in
            stdenvNoCC.mkDerivation {
              pname = "openai-tunnel-client";
              inherit version;
              src = fetchurl {
                url = "https://github.com/openai/tunnel-client/releases/download/v${version}/tunnel-client-runtime-v${version}-${asset}.zip";
                hash = hashes.${system};
              };
              nativeBuildInputs = [ unzip ];
              passthru.autoUpdate = true;
              passthru.updateScript = [
                "${python3}/bin/python3"
                "${../../scripts/update-binary-release.py}"
                "openai-tunnel-client"
              ];
              unpackPhase = ":";
              installPhase = ''
                mkdir -p "$out/bin"
                unzip -j "$src" tunnel-client-runtime -d "$out/bin"
                mv "$out/bin/tunnel-client-runtime" "$out/bin/tunnel-client"
                chmod +x "$out/bin/tunnel-client"
              '';
              meta = {
                description = "Tunnel client runtime";
                platforms = [
                  "aarch64-darwin"
                  "aarch64-linux"
                  "x86_64-linux"
                ];
                mainProgram = "tunnel-client";
              };
            }
          ) { };
        }
    )
  ];
}
