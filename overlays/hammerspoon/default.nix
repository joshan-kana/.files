_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs (prev.stdenv.hostPlatform.system == "aarch64-darwin") {
        hammerspoon =
          import ../../lib/mac-app.nix
            {
              inherit prev;
            }
            {
              release = {
                version = "1.1.1";
                hash = "sha256-EbsckPr1Qn83x71P5+q5d0rkPh1csCDFswiNrDKEnvo=";
              };
              pname = "hammerspoon";
              appName = "Hammerspoon.app";
              homepage = "https://www.hammerspoon.org";
              license = prev.lib.licenses.mit;
              passthru = {
                autoUpdate = true;
                updateUrl = "https://github.com/Hammerspoon/hammerspoon";
                updateGithubReleases = true;
                updateFilename = "overlays/hammerspoon/default.nix";
              };
              url =
                r:
                "https://github.com/Hammerspoon/hammerspoon/releases/download/${r.version}/Hammerspoon-${r.version}.zip";
              unpacker = prev.unzip;
            };
      }
    )
  ];
}
