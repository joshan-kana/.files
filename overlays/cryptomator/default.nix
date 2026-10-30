_: {
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
                version = "1.19.6";
                hash = "sha256-/fyO9QsQusoQeLep7fQE4zA2PIo6QP2in4bdXToKCwI=";
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
