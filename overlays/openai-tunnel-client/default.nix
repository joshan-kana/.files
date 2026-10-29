let
  package =
    {
      stdenvNoCC,
      fetchurl,
      unzip,
      python3,
    }:
    let
      version = "0.0.18";
      hashes = {
        aarch64-darwin = "sha256-gVbXgTWtNK5Fz1DDWjvI7hukycG5BbmO0CMsRKxWx+w=";
        aarch64-linux = "sha256-LfhMDAHoBhq2XD0FeIOYSLUtXkvld2mdF04QcluBFms=";
        x86_64-linux = "sha256-RYrMnUWrUy5oGPObz+6jI3SlEfOSd8nfKhhH6qvX98s=";
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
    };
in
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
          openai-tunnel-client = final.callPackage package { };
        }
    )
  ];
}
