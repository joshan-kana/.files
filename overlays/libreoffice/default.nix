_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs (prev.stdenv.hostPlatform.system == "aarch64-darwin") {
        libreoffice = import ../../lib/mac-app.nix { inherit prev; } {
          release = {
            version = "26.8.2";
            hash = "sha256-nyT+g6se1cles99YARnzKTL3E+V3/urAK/YZ+wB0m1U=";
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
            "https://download.documentfoundation.org/libreoffice/stable/${r.version}/mac/${
              if prev.stdenv.hostPlatform.isAarch64 then "aarch64" else "x86_64"
            }/LibreOffice_${r.version}_MacOS_${
              if prev.stdenv.hostPlatform.isAarch64 then "aarch64" else "x86-64"
            }.dmg";
        };
      }
    )
  ];
}
