_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        iterm2-mac =
          import ../../lib/mac-app.nix
            {
              inherit prev;
            }
            {
              release = {
                version = "3.7.6";
                hash = "sha256-u2EC6fV7vkGXm6fHscJdQRLppcIUJgbuzL4Y3H7gcG8=";
              };
              pname = "iterm2-mac";
              appName = "iTerm.app";
              homepage = "https://iterm2.com";
              license = prev.lib.licenses.gpl2Only;
              passthru = {
                autoUpdate = true;
                updateUrl = "https://formulae.brew.sh/api/cask/iterm2.json";
                updateRegex = ''"version"\s*:\s*"([^"]+)"'';
                updateScript = [
                  "${prev.python3}/bin/python3"
                  "${../../scripts/update-version.py}"
                  "iterm2-mac"
                  prev.stdenv.hostPlatform.system
                ];
                updateFilename = "overlays/iterm2/default.nix";
              };
              url =
                r:
                "https://iterm2.com/downloads/stable/iTerm2-${
                  builtins.replaceStrings [ "." ] [ "_" ] r.version
                }.zip";
              unpacker = prev.unzip;
            };
      }
    )
  ];
}
