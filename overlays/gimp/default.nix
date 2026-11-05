_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs (builtins.elem prev.stdenv.hostPlatform.system prev.lib.platforms.darwin) {
        gimp = import ../../lib/cask-app.nix { inherit prev; } {
          cask = "gimp";
          release = {
            version = "3.2.8";
            hashes = {
              aarch64-darwin = "sha256-BkBKN1EGt2E7o6FMfY2afL4YubnisgULty8xYsvPw5U=";
              x86_64-darwin = "sha256-d0ZIeYXXFDsZBpJQC1jVMXts6RamD4E5p2317qHpINs=";
            };
          };
          pname = "gimp";
          appName = "GIMP.app";
          homepage = "https://www.gimp.org";
          license = prev.lib.licenses.gpl3Plus;
          url =
            r:
            "https://download.gimp.org/gimp/v${prev.lib.versions.majorMinor r.version}/macos/gimp-${r.version}-${
              if prev.stdenv.hostPlatform.isAarch64 then "arm64" else "x86_64"
            }.dmg";
        };
      }
    )
  ];
}
