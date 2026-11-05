_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs (prev.stdenv.hostPlatform.system == "aarch64-darwin") {
        vial-mac =
          import ../../lib/mac-app.nix
            {
              inherit prev;
            }
            {
              release = {
                version = "0.7.5";
                hash = "sha256-tijbEfjfAS+q/M7vfes2tUghtQfUyXAzb4WlbIAOiHY=";
              };
              pname = "vial-mac";
              appName = "Vial.app";
              homepage = "https://get.vial.today";
              license = prev.lib.licenses.gpl2Only;
              passthru = {
                autoUpdate = true;
                updateUrl = "https://github.com/vial-kb/vial-gui";
                updateGithubReleases = true;
                updateFilename = "overlays/vial/default.nix";
              };
              url =
                r: "https://github.com/vial-kb/vial-gui/releases/download/v${r.version}/Vial-v${r.version}.dmg";
              unpacker = prev._7zz;
            };
      }
    )
  ];
}
