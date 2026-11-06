_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        aldente = import ../../lib/mac-app.nix { inherit prev; } {
          release = {
            version = "1.39.4";
            hash = "sha256-smNK5H9fhg+nX1vgqa6JsTbbtRQAOADtJWhz9DeqcBs=";
          };
          pname = "aldente";
          appName = "AlDente.app";
          homepage = "https://apphousekitchen.com";
          license = prev.lib.licenses.unfree;
          unpacker = prev._7zz;
          passthru = {
            autoUpdate = true;
            updateScript = [
              "${prev.python3}/bin/python3"
              "${../../scripts/update-version.py}"
              "https://formulae.brew.sh/api/cask/aldente.json"
              ''"version"\s*:\s*"([^"]+)"''
              "aldente"
              prev.stdenv.hostPlatform.system
              "overlays/aldente/default.nix"
            ];
            updateFilename = "overlays/aldente/default.nix";
          };
          url = r: "https://apphousekitchen.com/aldente/AlDente${r.version}.dmg";
        };
      }
    )
  ];
}
