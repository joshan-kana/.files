_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs (prev.stdenv.hostPlatform.system == "aarch64-darwin") {
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
          passthru = {
            autoUpdate = false;
            updateFilename = "overlays/aldente/default.nix";
          };
          url = r: "https://apphousekitchen.com/aldente/AlDente${r.version}.dmg";
        };
      }
    )
  ];
}
