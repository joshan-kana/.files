_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        notion-mac =
          import ../../lib/mac-app.nix
            {
              inherit prev;
            }
            {
              release = {
                version = "7.41.1";
                hash = "sha256-wUBajZ+ibKuNDSIQWfhIw5vs6wRJAmdT1QH6JhenLlA=";
              };
              pname = "notion-mac";
              appName = "Notion.app";
              homepage = "https://www.notion.so";
              license = prev.lib.licenses.unfree;
              passthru = {
                autoUpdate = true;
                updateScript = [
                  "${prev.python3}/bin/python3"
                  "${../../scripts/update-version.py}"
                  "https://formulae.brew.sh/api/cask/notion.json"
                  ''"version"\s*:\s*"([^"]+)"''
                  "notion-mac"
                  prev.stdenv.hostPlatform.system
                  "overlays/notion/default.nix"
                ];
                updateFilename = "overlays/notion/default.nix";
              };
              url = r: "https://desktop-release.notion-static.com/Notion-${r.version}-arm64.dmg";
            };
      }
    )
  ];
}
