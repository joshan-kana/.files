_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        libreoffice = import ../../lib/mac-app.nix { inherit prev; } {
          release = {
            version = "26.8.0.3";
            hash = "sha256-iFjYBY2k+GL0dVlIaBTmXvwnKU2mfF5LtWsAax7ln4k=";
          };
          pname = "libreoffice";
          appName = "LibreOffice.app";
          homepage = "https://www.libreoffice.org";
          license = prev.lib.licenses.mpl20;
          unpacker = prev._7zz;
          passthru = {
            autoUpdate = false;
            updateFilename = "overlays/libreoffice/default.nix";
          };
          url =
            r:
            "https://downloadarchive.documentfoundation.org/libreoffice/old/${r.version}/mac/${
              if prev.stdenv.hostPlatform.isAarch64 then "aarch64" else "x86_64"
            }/LibreOffice_${r.version}_MacOS_${
              if prev.stdenv.hostPlatform.isAarch64 then "aarch64" else "x86-64"
            }.dmg";
        };
      }
    )
  ];
}
