_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        linear =
          import ../../lib/mac-app.nix
            {
              inherit prev;
            }
            {
              release = {
                version = "1.32.8";
                hash = "sha256-CNQrkXvEQGgjHUep4Urp/awsqV+mtFHoEPzaD3Vu1KM=";
              };
              pname = "linear";
              appName = "Linear.app";
              homepage = "https://linear.app";
              license = prev.lib.licenses.unfree;
              passthru = rec {
                autoUpdate = true;
                updateUrl = "https://formulae.brew.sh/api/cask/linear.json";
                updateRegex = ''"version"\s*:\s*"([^"]+)"'';
                updateScript = [
                  "${prev.python3}/bin/python3"
                  "${../../scripts/update-version.py}"
                  updateFilename
                  prev.stdenv.hostPlatform.system
                ];
                updateFilename = "overlays/linear/default.nix";
              };
              url = r: "https://releases.linear.app/Linear-${r.version}-universal.dmg";
            };
      }
    )
  ];
}
