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
                version = "7.42.3";
                hash = "sha256-R3CElpeLFsv1+52n2rG0SW8+f93swVrfeFIjOZNz06M=";
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
