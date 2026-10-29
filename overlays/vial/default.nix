_: {
  dotfiles.updatePolicy."vial-mac" = "auto";
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        vial-mac =
          import ../../lib/mac-app.nix
            {
              inherit prev;
            }
            {
              token = "vial";
              release = {
                version = "0.7.5";
                hash = "sha256-tijbEfjfAS+q/M7vfes2tUghtQfUyXAzb4WlbIAOiHY=";
              };
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
