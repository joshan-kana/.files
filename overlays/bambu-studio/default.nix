{ lib, system, ... }: {
  dotfiles.updatePolicy."bambu-studio" = lib.mkIf (lib.systems.elaborate system).isDarwin "auto";
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        bambu-studio =
          import ../../lib/mac-app.nix
            {
              inherit prev;
            }
            {
              token = "bambu-studio";
              release = {
                version = "02.08.02.61,20260820225108";
                hash = "sha256-z2SKlYWPtjDhNTxJhwON9g1sqraT8YQR+5X7gJ8taSY=";
              };
              pname = "bambu-studio";
              appName = "BambuStudio.app";
              homepage = "https://github.com/bambulab/BambuStudio";
              license = prev.lib.licenses.agpl3Only;
              url =
                r:
                "https://github.com/bambulab/BambuStudio/releases/download/v${r.version}/Bambu_Studio_mac-v${r.version}-${builtins.elemAt r.versions 1}.dmg";
            };
      }
    )
  ];
}
