{ inputs, ... }: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        prusa-slicer =
          import ../lib/mac-app.nix
            {
              inherit prev inputs;
            }
            {
              token = "prusaslicer";
              pname = "prusa-slicer";
              appName = "PrusaSlicer.app";
              homepage = "https://github.com/prusa3d/PrusaSlicer";
              license = prev.lib.licenses.agpl3Only;
              url =
                r:
                "https://github.com/prusa3d/PrusaSlicer/releases/download/version_${r.version}/PrusaSlicer-${r.version}.dmg";
            };
      }
    )
  ];
}
