{ inputs, ... }: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        raspberry-pi-imager-mac =
          import ../lib/mac-app.nix
            {
              inherit prev inputs;
            }
            {
              token = "raspberry-pi-imager";
              pname = "raspberry-pi-imager-mac";
              appName = "Raspberry Pi Imager.app";
              homepage = "https://www.raspberrypi.com/software/";
              license = prev.lib.licenses.asl20;
              url =
                r:
                "https://github.com/raspberrypi/rpi-imager/releases/download/v${r.version}/rpi-imager-v${r.version}.dmg";
            };
      }
    )
  ];
}
