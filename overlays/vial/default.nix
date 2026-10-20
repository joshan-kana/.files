{ inputs, ... }: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        vial-mac =
          import ../lib/mac-app.nix
            {
              inherit prev inputs;
            }
            {
              token = "vial";
              pname = "vial-mac";
              appName = "Vial.app";
              homepage = "https://get.vial.today";
              license = prev.lib.licenses.gpl2Only;
              url =
                r: "https://github.com/vial-kb/vial-gui/releases/download/v${r.version}/Vial-v${r.version}.dmg";
              unpacker = prev._7zz;
            };
      }
    )
  ];
}
