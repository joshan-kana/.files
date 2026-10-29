_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        reaper-mac =
          import ../../lib/mac-app.nix
            {
              inherit prev;
            }
            {
              token = "reaper";
              release = {
                version = "7.84";
                hash = "sha256-n2h69TSAoetSg5d+kIhFOfDnT0HoS6lTRV3H7NPUJTA=";
              };
              pname = "reaper-mac";
              appName = "REAPER.app";
              homepage = "https://www.reaper.fm";
              license = prev.lib.licenses.unfree;
              url =
                r:
                "https://dlcf.reaper.fm/${builtins.elemAt (prev.lib.splitString "." r.version) 0}.x/reaper${builtins.concatStringsSep "" (prev.lib.take 2 (prev.lib.splitString "." r.version))}_universal.dmg";
            };
      }
    )
  ];
}
