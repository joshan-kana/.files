_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs (builtins.elem prev.stdenv.hostPlatform.system prev.lib.platforms.darwin) {
        libreoffice = import ../../lib/cask-app.nix { inherit prev; } {
          cask = "libreoffice";
          release = {
            version = "26.8.2";
            hashes = {
              aarch64-darwin = "sha256-nyT+g6se1cles99YARnzKTL3E+V3/urAK/YZ+wB0m1U=";
              x86_64-darwin = "sha256-CvBid5zBf2+FKRiyQkx0X33S0g1R1/uKCSXrkuwEF6c=";
            };
          };
          pname = "libreoffice";
          appName = "LibreOffice.app";
          homepage = "https://www.libreoffice.org";
          license = prev.lib.licenses.mpl20;
          unpacker = prev._7zz;
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
