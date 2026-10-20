{ inputs, ... }: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        reaper-mac =
          import ../lib/mac-app.nix
            {
              inherit prev inputs;
            }
            {
              token = "reaper";
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
