_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        heroic =
          import ../../lib/mac-app.nix
            {
              inherit prev;
            }
            {
              release = {
                version = "2.22.4";
                hash = "sha256-KdVHakvxrqTdPJByU6SboyciI7QgxbrIxymVs2tXzYk=";
              };
              pname = "heroic";
              appName = "Heroic.app";
              homepage = "https://heroicgameslauncher.com";
              license = prev.lib.licenses.gpl3Only;
              passthru = {
                autoUpdate = true;
                updateUrl = "https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher";
                updateGithubReleases = true;
                updateFilename = "overlays/heroic/default.nix";
              };
              url =
                r:
                "https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/releases/download/v${r.version}/Heroic-${r.version}-macOS-arm64.dmg";
            };
      }
    )
  ];
}
