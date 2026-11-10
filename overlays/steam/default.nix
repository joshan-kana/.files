_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        steam = import ../../lib/mac-app.nix { inherit prev; } {
          pname = "steam";
          release = {
            version = "6.1";
            build = "984652b88a9737e3f4e77c656d9ffa67d5042c2c";
            hash = "sha256-i/TOi0vLxQ9kKYjJVVWfYF56h3NyEW56Kz/RNVAEvts=";
          };
          appName = "Steam.app";
          homepage = "https://store.steampowered.com/";
          license = prev.lib.licenses.unfree;
          unpacker = prev.unzip;
          unpackCmd = ''unzip -q "$curSrc" && tar -xzf SteamMacBootstrapper.tar.gz'';
          passthru.autoUpdate = false;
          url = r: "https://client-update.steamstatic.com/appdmg_osx.zip.${r.build}";
        };
      }
    )
  ];
}
