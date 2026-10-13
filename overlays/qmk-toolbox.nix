{ inputs, ... }: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        qmk-toolbox-mac =
          import ./lib/mac-app.nix
            {
              inherit prev inputs;
            }
            {
              token = "qmk-toolbox";
              pname = "qmk-toolbox-mac";
              appName = "QMK Toolbox.app";
              homepage = "https://github.com/qmk/qmk_toolbox";
              license = prev.lib.licenses.mit;
              url = r: "https://github.com/qmk/qmk_toolbox/releases/download/${r.version}/QMK.Toolbox.app.zip";
              unpacker = prev.unzip;
            };
      }
    )
  ];
}
