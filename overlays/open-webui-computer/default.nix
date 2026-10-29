_: {
  nixpkgs.overlays = [
    (
      final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
        open-webui-computer = final.callPackage (
          {
            stdenvNoCC,
            python3Packages,
          }:
          let
            version = "0.9.21";
          in
          stdenvNoCC.mkDerivation {
            pname = "cptr";
            inherit version;

            src = python3Packages.fetchPypi {
              pname = "cptr";
              inherit version;
              format = "wheel";
              dist = "py3";
              python = "py3";
              hash = "sha256-J5AzSijym8HttPT4GyqEmGOQWb9OyULnV4CxDAxrTRg=";
            };

            # Keep the PyPI wheel pin separate from Open WebUI itself.
            passthru.updateUrl = "https://pypi/project/cptr";

            passthru.autoUpdate = true;
            dontUnpack = true;
            installPhase = ''
              mkdir -p "$out"
              cp "$src" "$out/"
            '';
          }
        ) { };
      }
    )
  ];
}
