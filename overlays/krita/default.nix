_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        krita = import ../../lib/mac-app.nix { inherit prev; } {
          release = {
            version = "5.3.4";
            hash = "sha256-jmZTnji4vs/TEJOncBFEw0DBeJNwt14Qo3AzInOSddc=";
          };
          pname = "krita";
          appName = "krita.app";
          homepage = "https://krita.org";
          license = prev.lib.licenses.gpl3Only;
          unpacker = prev._7zz;
          unpackCmd = ''
            7zz x -sns- -snld20 -y "$curSrc"
          '';
          passthru = {
            autoUpdate = false;
            updateFilename = "overlays/krita/default.nix";
          };
          url = r: "https://download.kde.org/stable/krita/${r.version}/krita-${r.version}-signed.dmg";
        };
      }
    )
  ];
}
