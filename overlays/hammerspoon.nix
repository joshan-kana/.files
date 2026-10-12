_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        hammerspoon = prev.stdenvNoCC.mkDerivation rec {
          pname = "hammerspoon";
          version = "1.1.1";

          src = prev.fetchzip {
            url = "https://github.com/Hammerspoon/hammerspoon/releases/download/${version}/Hammerspoon-${version}.zip";
            hash = "sha256-PUv1LL2fSLHvOTb9flw+scrDFYyJ81mrFGjSk73k1S8=";
            stripRoot = false;
          };

          dontConfigure = true;
          dontBuild = true;
          # Preserve the upstream sealed bundle; Nix fixups rewrite bundled scripts.
          dontFixup = true;
          installPhase = ''
            runHook preInstall
            mkdir -p "$out/Applications"
            cp -R "$src/Hammerspoon.app" "$out/Applications/"
            runHook postInstall
          '';

          meta = {
            description = "Hammerspoon macOS automation app";
            homepage = "https://www.hammerspoon.org";
            platforms = prev.lib.platforms.darwin;
            license = prev.lib.licenses.mit;
          };
        };
      }
    )
  ];
}
