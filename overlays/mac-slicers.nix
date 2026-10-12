_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        bambu-studio = prev.stdenvNoCC.mkDerivation {
          pname = "bambu-studio";
          version = "02.08.02.61";

          src = prev.fetchurl {
            url = "https://github.com/bambulab/BambuStudio/releases/download/v02.08.02.61/Bambu_Studio_mac-v02.08.02.61-20260820225108.dmg";
            hash = "sha256-z2SKlYWPtjDhNTxJhwON9g1sqraT8YQR+5X7gJ8taSY=";
          };

          nativeBuildInputs = [ prev.undmg ];
          sourceRoot = ".";
          dontBuild = true;
          dontFixup = true;

          installPhase = ''
            runHook preInstall
            mkdir -p "$out/Applications"
            cp -R ./BambuStudio.app "$out/Applications/"
            runHook postInstall
          '';

          meta = {
            description = "Bambu Studio 3D printer slicer";
            homepage = "https://github.com/bambulab/BambuStudio";
            license = prev.lib.licenses.agpl3Only;
            platforms = prev.lib.platforms.darwin;
            sourceProvenance = [ prev.lib.sourceTypes.binaryNativeCode ];
          };
        };
        prusa-slicer = prev.stdenvNoCC.mkDerivation {
          pname = "prusa-slicer";
          version = "2.9.6";

          src = prev.fetchurl {
            url = "https://github.com/prusa3d/PrusaSlicer/releases/download/version_2.9.6/PrusaSlicer-2.9.6.dmg";
            hash = "sha256-lP17ip+HyWMeHHFzmxWxhPxfTAzqvWkHLxx48imk/kA=";
          };

          nativeBuildInputs = [ prev.undmg ];
          sourceRoot = ".";
          dontBuild = true;
          dontFixup = true;

          installPhase = ''
            runHook preInstall
            mkdir -p "$out/Applications"
            app="$(find . -type d -name PrusaSlicer.app -print -quit)"
            test -n "$app"
            cp -R "$app" "$out/Applications/"
            runHook postInstall
          '';

          meta = {
            description = "PrusaSlicer 3D printer slicer";
            homepage = "https://github.com/prusa3d/PrusaSlicer";
            license = prev.lib.licenses.agpl3Only;
            platforms = prev.lib.platforms.darwin;
            sourceProvenance = [ prev.lib.sourceTypes.binaryNativeCode ];
          };
        };
      }
    )
  ];
}
