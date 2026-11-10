_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        arduino-ide =
          import ../../lib/mac-app.nix
            {
              inherit prev;
            }
            {
              release = {
                version = "2.3.10";
                hash = "sha256-iBGGDch4K2zWuwB26SFSVYSfQEsbnm84Bp/cT1xDZI4=";
              };
              pname = "arduino-ide";
              appName = "Arduino IDE.app";
              homepage = "https://www.arduino.cc/en/software";
              license = prev.lib.licenses.agpl3Only;
              passthru = {
                autoUpdate = true;
                updateUrl = "https://github.com/arduino/arduino-ide";
                updateGithubReleases = true;
                updateFilename = "overlays/arduino-ide/default.nix";
              };
              url =
                r:
                "https://github.com/arduino/arduino-ide/releases/download/${r.version}/arduino-ide_${r.version}_macOS_ARM64.dmg";
              unpacker = prev._7zz;
            };
      }
    )
  ];
}
