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
              token = "notion";
              release = {
                version = "7.41.1";
                hash = "sha256-wUBajZ+ibKuNDSIQWfhIw5vs6wRJAmdT1QH6JhenLlA=";
              };
              pname = "notion-mac";
              appName = "Notion.app";
              homepage = "https://www.notion.so";
              license = prev.lib.licenses.unfree;
              url = r: "https://desktop-release.notion-static.com/Notion-${r.version}-arm64.dmg";
            };
      }
    )
  ];
}
