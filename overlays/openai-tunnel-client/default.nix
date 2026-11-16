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
            }:
            let
              version = "0.0.21";
              hashes = {
                aarch64-darwin = "sha256-+41VUjLtL5NWR+z7CgH9ggfw9amAqrRAB+uRe+t0gu0=";
                aarch64-linux = "sha256-Fkt1fuDAOJUI5uF+EpsAgPdzPYsxCOC9HX/jHgEBb5c=";
                x86_64-linux = "sha256-+lMYK3Zq6s62Uthq7ikcSNr3uQtdc1htujcPTBgBMl4=";
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
              passthru.updateGroup = "openai-tunnel-client";
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
