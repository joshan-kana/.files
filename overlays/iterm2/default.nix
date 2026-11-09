_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        iterm2 =
          import ../../lib/mac-app.nix
            {
              inherit prev;
            }
            {
              release = {
                version = "3.7.7";
                hash = "sha256-VJ6yshRk1/RgYWXlHDamsaJSrJp5lYIookAVJBJ1naI=";
              };
              pname = "iterm2";
              appName = "iTerm.app";
              homepage = "https://iterm2.com";
              license = prev.lib.licenses.gpl2Only;
              passthru = rec {
                autoUpdate = true;
                updateUrl = "https://formulae.brew.sh/api/cask/iterm2.json";
                updateRegex = ''"version"\s*:\s*"([^"]+)"'';
                updateScript = [
                  "${prev.python3}/bin/python3"
                  "${../../scripts/update-version.py}"
                  updateFilename
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
