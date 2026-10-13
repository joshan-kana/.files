{ inputs, ... }: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        arduino-ide-mac =
          import ./lib/mac-app.nix
            {
              inherit prev inputs;
            }
            {
              token = "arduino-ide";
              pname = "arduino-ide-mac";
              appName = "Arduino IDE.app";
              homepage = "https://www.arduino.cc/en/software";
              license = prev.lib.licenses.agpl3Only;
              url =
                r:
                "https://github.com/arduino/arduino-ide/releases/download/${r.version}/arduino-ide_${r.version}_macOS_ARM64.dmg";
              unpacker = prev._7zz;
            };
      }
    )
  ];
}
