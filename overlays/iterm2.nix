{ inputs, ... }:
{
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        iterm2-mac =
          import ./lib/mac-app.nix
            {
              inherit prev inputs;
            }
            {
              token = "iterm2";
              pname = "iterm2-mac";
              appName = "iTerm.app";
              homepage = "https://iterm2.com";
              license = prev.lib.licenses.gpl2Only;
              url =
                r:
                "https://iterm2.com/downloads/stable/iTerm2-${
                  builtins.replaceStrings [ "." ] [ "_" ] r.version
                }.zip";
              unpacker = prev.unzip;
            };
      }
    )
  ];
}
