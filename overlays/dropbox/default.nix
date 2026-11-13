_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        dropbox = import ../../lib/mac-app.nix { inherit prev; } {
          pname = "dropbox";
          release = {
            version = "278.4.4020";
            hash = "sha256-NhE4US2fNnUW+lNiMNlvg49eZDuWE6nR0sanBoafRe0=";
          };
          appName = "Dropbox.app";
          homepage = "https://dropbox.com/";
          license = prev.lib.licenses.unfree;
          passthru = rec {
            autoUpdate = true;
            updateUrl = "https://formulae.brew.sh/api/cask/dropbox.json";
            updateRegex = ''"version"\s*:\s*"([^"]+)"'';
            updateScript = [
              "${prev.python3}/bin/python3"
              "${../../scripts/update-version.py}"
              updateFilename
              prev.stdenv.hostPlatform.system
            ];
            updateFilename = "overlays/dropbox/default.nix";
          };
          url = r: "https://edge.dropboxstatic.com/dbx-releng/client/Dropbox%20${r.version}.arm64.dmg";
        };
      }
    )
  ];
}
