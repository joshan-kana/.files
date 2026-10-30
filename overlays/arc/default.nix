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
              token = "arc";
              release = {
                version = "1.171.0,89666";
                hash = "sha256-73GOq7IH5dQrwJdaCxcMgclN4PpoTCwznx9rOEY+Y0s=";
              };
              pname = "arc-mac";
              appName = "Arc.app";
              homepage = "https://arc.net";
              license = prev.lib.licenses.unfree;
              url =
                r:
                "https://releases.arc.net/release/Arc-${builtins.elemAt r.versions 0}-${builtins.elemAt r.versions 1}.zip";
              unpacker = prev.unzip;
            };
      }
    )
  ];
}
