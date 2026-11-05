_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs (builtins.elem prev.stdenv.hostPlatform.system prev.lib.platforms.darwin) {
        aldente = import ../../lib/cask-app.nix { inherit prev; } {
          cask = "aldente";
          release = {
            version = "1.40.1";
            hash = "sha256-y+P0fxsIud5XYMr0a0llpuyAsf+LXwQ6foO5UrAGyiM=";
          };
          pname = "aldente";
          appName = "AlDente.app";
          homepage = "https://apphousekitchen.com";
          license = prev.lib.licenses.unfree;
          unpacker = prev._7zz;
          url = r: "https://apphousekitchen.com/aldente/AlDente${r.version}.dmg";
        };
      }
    )
  ];
}
