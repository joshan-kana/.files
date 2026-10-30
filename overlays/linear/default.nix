_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        linear-mac =
          import ../../lib/mac-app.nix
            {
              inherit prev;
            }
            {
              token = "linear";
              release = {
                version = "1.32.8";
                hash = "sha256-CNQrkXvEQGgjHUep4Urp/awsqV+mtFHoEPzaD3Vu1KM=";
              };
              pname = "linear-mac";
              appName = "Linear.app";
              homepage = "https://linear.app";
              license = prev.lib.licenses.unfree;
              url = r: "https://releases.linear.app/Linear-${r.version}-universal.dmg";
            };
      }
    )
  ];
}
