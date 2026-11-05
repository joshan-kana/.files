_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs (prev.stdenv.hostPlatform.system == "aarch64-darwin") {
        reaper-mac =
          import ../../lib/mac-app.nix
            {
              inherit prev;
            }
            {
              release = {
                version = "7.84";
                hash = "sha256-n2h69TSAoetSg5d+kIhFOfDnT0HoS6lTRV3H7NPUJTA=";
              };
              pname = "reaper-mac";
              appName = "REAPER.app";
              homepage = "https://www.reaper.fm";
              license = prev.lib.licenses.unfree;
              passthru = {
                autoUpdate = false;
                updateFilename = "overlays/reaper/default.nix";
              };
              url =
                r:
                "https://dlcf.reaper.fm/${builtins.elemAt (prev.lib.splitString "." r.version) 0}.x/reaper${builtins.concatStringsSep "" (prev.lib.take 2 (prev.lib.splitString "." r.version))}_universal.dmg";
            };
      }
    )
  ];
}
