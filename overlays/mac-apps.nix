_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      let
        macDmg =
          {
            pname,
            version,
            url,
            hash,
            appName,
            homepage,
            license,
            unpacker ? prev.undmg,
          }:
          prev.stdenvNoCC.mkDerivation {
            inherit pname version;
            src = prev.fetchurl { inherit url hash; };
            nativeBuildInputs = [ unpacker ];
            sourceRoot = ".";
            dontBuild = true;
            # Keep upstream sealed application bundles unchanged.
            dontFixup = true;
            installPhase = ''
              runHook preInstall
              mkdir -p "$out/Applications"
              cp -R "$(find . -type d -name '${appName}' -print -quit)" "$out/Applications/"
              runHook postInstall
            '';
            meta = {
              inherit homepage license;
              platforms = prev.lib.platforms.darwin;
              sourceProvenance = [ prev.lib.sourceTypes.binaryNativeCode ];
            };
          };
      in
      {
        arduino-ide-mac = macDmg {
          pname = "arduino-ide-mac";
          version = "2.3.10";
          url = "https://github.com/arduino/arduino-ide/releases/download/2.3.10/arduino-ide_2.3.10_macOS_ARM64.dmg";
          hash = "sha256-iBGGDch4K2zWuwB26SFSVYSfQEsbnm84Bp/cT1xDZI4=";
          appName = "Arduino IDE.app";
          homepage = "https://www.arduino.cc/en/software";
          license = prev.lib.licenses.agpl3Only;
          unpacker = prev._7zz;
        };

        cryptomator-mac = macDmg {
          pname = "cryptomator-mac";
          version = "1.19.3";
          url = "https://github.com/cryptomator/cryptomator/releases/download/1.19.3/Cryptomator-1.19.3-arm64.dmg";
          hash = "sha256-C/6MauuXrPY4gQ4+V2AW21ELx79xNm3ADzx+6poxTyM=";
          appName = "Cryptomator.app";
          homepage = "https://cryptomator.org";
          license = prev.lib.licenses.gpl3Only;
        };

        raspberry-pi-imager-mac = macDmg {
          pname = "raspberry-pi-imager-mac";
          version = "2.0.12";
          url = "https://github.com/raspberrypi/rpi-imager/releases/download/v2.0.12/rpi-imager-v2.0.12.dmg";
          hash = "sha256-FbGpTHEsADJ1CFVlPCvxKdzrQBMp+84Kg9fPBdxYpCE=";
          appName = "Raspberry Pi Imager.app";
          homepage = "https://www.raspberrypi.com/software/";
          license = prev.lib.licenses.asl20;
        };

        heroic-mac = macDmg {
          pname = "heroic-mac";
          version = "2.22.3";
          url = "https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/releases/download/v2.22.3/Heroic-2.22.3-macOS-arm64.dmg";
          hash = "sha256-IwF+5s5umCritFE2VriHtpNBS1HnIFyKxUs8tS8m4Bk=";
          appName = "Heroic.app";
          homepage = "https://heroicgameslauncher.com";
          license = prev.lib.licenses.gpl3Only;
        };

        notion-mac = macDmg {
          pname = "notion-mac";
          version = "7.37.1";
          url = "https://desktop-release.notion-static.com/Notion-7.37.1-arm64.dmg";
          hash = "sha256-cwdz7UTHgBCWj6OvnsXU5bkQIRScvwS3KXmQkcp4WlE=";
          appName = "Notion.app";
          homepage = "https://www.notion.so";
          license = prev.lib.licenses.unfree;
        };

        linear-mac = macDmg {
          pname = "linear-mac";
          version = "1.32.4";
          url = "https://releases.linear.app/Linear-1.32.4-universal.dmg";
          hash = "sha256-uuEHj6v1ty2ITDu7pCNRF+kgcK3LpAfNwwr7OTPxTTE=";
          appName = "Linear.app";
          homepage = "https://linear.app";
          license = prev.lib.licenses.unfree;
        };

        reaper-mac = macDmg {
          pname = "reaper-mac";
          version = "7.82";
          url = "https://dlcf.reaper.fm/7.x/reaper782_universal.dmg";
          hash = "sha256-J7H/YD1ueUHxWOHqbj6ACeTYRHhX4G3wAkGQDEL/BJE=";
          appName = "REAPER.app";
          homepage = "https://www.reaper.fm";
          license = prev.lib.licenses.unfree;
        };

        vial-mac = macDmg {
          pname = "vial-mac";
          version = "0.7.5";
          url = "https://github.com/vial-kb/vial-gui/releases/download/v0.7.5/Vial-v0.7.5.dmg";
          hash = "sha256-tijbEfjfAS+q/M7vfes2tUghtQfUyXAzb4WlbIAOiHY=";
          appName = "Vial.app";
          homepage = "https://get.vial.today";
          license = prev.lib.licenses.gpl2Only;
          unpacker = prev._7zz;
        };
      }
    )
  ];
}
