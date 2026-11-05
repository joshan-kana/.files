_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        arc-mac =
          import ../../lib/mac-app.nix
            {
              inherit prev;
            }
            {
              release = {
                version = "1.171.0";
                build = "89666";
                hash = "sha256-73GOq7IH5dQrwJdaCxcMgclN4PpoTCwznx9rOEY+Y0s=";
              };
              pname = "arc-mac";
              appName = "Arc.app";
              homepage = "https://arc.net";
              license = prev.lib.licenses.unfree;
              passthru = {
                autoUpdate = false;
                updateFilename = "overlays/arc/default.nix";
              };
              url = r: "https://releases.arc.net/release/Arc-${r.version}-${r.build}.zip";
              unpacker = prev.unzip;
            };
      }
    )
  ];
}
