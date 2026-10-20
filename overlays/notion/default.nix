{ inputs, ... }: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        notion-mac =
          import ../lib/mac-app.nix
            {
              inherit prev inputs;
            }
            {
              token = "notion";
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
