{ inputs, ... }: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        hammerspoon =
          import ../lib/mac-app.nix
            {
              inherit prev inputs;
            }
            {
              token = "hammerspoon";
              pname = "hammerspoon";
              appName = "Hammerspoon.app";
              homepage = "https://www.hammerspoon.org";
              license = prev.lib.licenses.mit;
              url =
                r:
                "https://github.com/Hammerspoon/hammerspoon/releases/download/${r.version}/Hammerspoon-${r.version}.zip";
              unpacker = prev.unzip;
            };
      }
    )
  ];
}
