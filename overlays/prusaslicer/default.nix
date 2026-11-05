_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        prusa-slicer =
          import ../../lib/mac-app.nix
            {
              inherit prev;
            }
            {
              release = {
                version = "2.9.6";
                hash = "sha256-lP17ip+HyWMeHHFzmxWxhPxfTAzqvWkHLxx48imk/kA=";
              };
              pname = "prusa-slicer";
              appName = "PrusaSlicer.app";
              homepage = "https://github.com/prusa3d/PrusaSlicer";
              license = prev.lib.licenses.agpl3Only;
              passthru = {
                autoUpdate = true;
                updateUrl = "https://github.com/prusa3d/PrusaSlicer";
                updateGithubReleases = true;
                updateRegex = "version_(.*)";
                updateFilename = "overlays/prusaslicer/default.nix";
              };
              url =
                r:
                "https://github.com/prusa3d/PrusaSlicer/releases/download/version_${r.version}/PrusaSlicer-${r.version}.dmg";
            };
      }
    )
  ];
}
