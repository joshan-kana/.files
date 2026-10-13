{ inputs, ... }: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        bambu-studio =
          import ./lib/mac-app.nix
            {
              inherit prev inputs;
            }
            {
              token = "bambu-studio";
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
