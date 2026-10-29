_: {
  dotfiles.updatePolicy."linear-mac" = "auto";
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
                version = "1.32.7";
                hash = "sha256-mZGa7z6jw/YuKQA3LOSi9jd3CVuDVmTvangzLiSuUGU=";
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
