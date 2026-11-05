_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs (prev.stdenv.hostPlatform.system == "aarch64-darwin") {
        qmk-toolbox-mac =
          import ../../lib/mac-app.nix
            {
              inherit prev;
            }
            {
              release = {
                version = "0.3.4";
                hash = "sha256-CgUUltkU1YinVu5L4u6KoD3J1dMoczAS5vBv6k9CXQg=";
              };
              pname = "qmk-toolbox-mac";
              appName = "QMK Toolbox.app";
              homepage = "https://github.com/qmk/qmk_toolbox";
              license = prev.lib.licenses.mit;
              passthru = {
                autoUpdate = true;
                updateUrl = "https://github.com/qmk/qmk_toolbox";
                updateGithubReleases = true;
                updateFilename = "overlays/qmk-toolbox/default.nix";
              };
              url = r: "https://github.com/qmk/qmk_toolbox/releases/download/${r.version}/QMK.Toolbox.app.zip";
              unpacker = prev.unzip;
            };
      }
    )
  ];
}
