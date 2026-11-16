_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        reaper =
          import ../../lib/mac-app.nix
            {
              inherit prev;
            }
            {
              release = {
                version = "7.86";
                hash = "sha256-JZ8UDszZGbV9H69bKFGjXKB33ZmTynzF6yjW1Xt3eGY=";
              };
              pname = "reaper";
              appName = "REAPER.app";
              homepage = "https://www.reaper.fm";
              license = prev.lib.licenses.unfree;
              passthru = rec {
                autoUpdate = true;
                updateUrl = "https://formulae.brew.sh/api/cask/reaper.json";
                updateRegex = ''"version"\s*:\s*"([^"]+)"'';
                updateScript = [
                  "${prev.python3}/bin/python3"
                  "${../../scripts/update-version.py}"
                  updateFilename
                  prev.stdenv.hostPlatform.system
                ];
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
