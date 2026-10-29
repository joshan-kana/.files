_: {
  dotfiles.updatePolicy."cryptomator-mac" = "auto";
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        cryptomator-mac =
          import ../../lib/mac-app.nix
            {
              inherit prev;
            }
            {
              token = "cryptomator";
              release = {
                version = "1.19.4";
                hash = "sha256-QTpIgG56ovTEFrhOOiPby6g64gsq1VU0t5j222WoWGA=";
              };
              pname = "cryptomator-mac";
              appName = "Cryptomator.app";
              homepage = "https://cryptomator.org";
              license = prev.lib.licenses.gpl3Only;
              url =
                r:
                "https://github.com/cryptomator/cryptomator/releases/download/${r.version}/Cryptomator-${r.version}-arm64.dmg";
            };
      }
    )
  ];
}
