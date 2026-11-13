_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        notion-app =
          import ../../lib/mac-app.nix
            {
              inherit prev;
            }
            {
              release = {
                version = "7.43.2";
                hash = "sha256-WJG8rjx6FrdoRWJ0hO6+PkcB0clfP55Fi3+F/qIwb5Y=";
              };
              pname = "notion-app";
              appName = "Notion.app";
              homepage = "https://www.notion.so";
              license = prev.lib.licenses.unfree;
              passthru = rec {
                autoUpdate = true;
                updateUrl = "https://formulae.brew.sh/api/cask/notion.json";
                updateRegex = ''"version"\s*:\s*"([^"]+)"'';
                updateScript = [
                  "${prev.python3}/bin/python3"
                  "${../../scripts/update-version.py}"
                  updateFilename
                  prev.stdenv.hostPlatform.system
                ];
                updateFilename = "overlays/notion/default.nix";
              };
              url = r: "https://desktop-release.notion-static.com/Notion-${r.version}-arm64.dmg";
            };
      }
    )
  ];
}
