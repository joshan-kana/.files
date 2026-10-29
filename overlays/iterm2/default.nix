_: {
  dotfiles.updatePolicy."iterm2-mac" = "auto";
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        iterm2-mac =
          import ../../lib/mac-app.nix
            {
              inherit prev;
            }
            {
              token = "iterm2";
              release = {
                version = "3.7.6";
                hash = "sha256-u2EC6fV7vkGXm6fHscJdQRLppcIUJgbuzL4Y3H7gcG8=";
              };
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
