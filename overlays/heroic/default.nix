_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        heroic-mac =
          import ../lib/mac-app.nix
            {
              inherit prev;
            }
            {
              token = "heroic";
              release = {
                version = "2.22.4";
                hash = "sha256-KdVHakvxrqTdPJByU6SboyciI7QgxbrIxymVs2tXzYk=";
              };
              pname = "heroic-mac";
              appName = "Heroic.app";
              homepage = "https://heroicgameslauncher.com";
              license = prev.lib.licenses.gpl3Only;
              url =
                r:
                "https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/releases/download/v${r.version}/Heroic-${r.version}-macOS-arm64.dmg";
            };
      }
    )
  ];
}
