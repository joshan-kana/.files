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
              release = {
                version = "1.32.8";
                hash = "sha256-CNQrkXvEQGgjHUep4Urp/awsqV+mtFHoEPzaD3Vu1KM=";
              };
              pname = "linear-mac";
              appName = "Linear.app";
              homepage = "https://linear.app";
              license = prev.lib.licenses.unfree;
              passthru = {
                autoUpdate = true;
                updateScript = [
                  "${prev.python3}/bin/python3"
                  "${../../scripts/update-version.py}"
                  "https://formulae.brew.sh/api/cask/linear.json"
                  ''"version"\s*:\s*"([^"]+)"''
                  "linear-mac"
                  prev.stdenv.hostPlatform.system
                  "overlays/linear/default.nix"
                ];
                updateFilename = "overlays/linear/default.nix";
              };
              url = r: "https://releases.linear.app/Linear-${r.version}-universal.dmg";
            };
      }
    )
  ];
}
