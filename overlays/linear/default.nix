{ inputs, ... }: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        linear-mac =
          import ../lib/mac-app.nix
            {
              inherit prev inputs;
            }
            {
              token = "linear";
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
