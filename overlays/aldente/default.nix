_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        aldente = import ../../lib/mac-app.nix { inherit prev; } {
          release = {
            version = "1.40.1";
            hash = "sha256-y+P0fxsIud5XYMr0a0llpuyAsf+LXwQ6foO5UrAGyiM=";
          };
          pname = "aldente";
          appName = "AlDente.app";
          homepage = "https://apphousekitchen.com";
          license = prev.lib.licenses.unfree;
          unpacker = prev._7zz;
          passthru = rec {
            autoUpdate = true;
            updateUrl = "https://formulae.brew.sh/api/cask/aldente.json";
            updateRegex = ''"version"\s*:\s*"([^"]+)"'';
            updateScript = [
              "${prev.python3}/bin/python3"
              "${../../scripts/update-version.py}"
              updateFilename
              prev.stdenv.hostPlatform.system
            ];
            updateFilename = "overlays/aldente/default.nix";
          };
          url = r: "https://apphousekitchen.com/aldente/AlDente${r.version}.dmg";
        };
      }
    )
  ];
}
