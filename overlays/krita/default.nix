_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs (builtins.elem prev.stdenv.hostPlatform.system prev.lib.platforms.darwin) {
        krita = import ../../lib/cask-app.nix { inherit prev; } {
          cask = "krita";
          release = {
            version = "5.3.4.1";
            hash = "sha256-Ux4mHaH9jVxGjPzU7r0W6e32qzIOiUBtKHXy5DwRSN4=";
          };
          pname = "krita";
          appName = "krita.app";
          homepage = "https://krita.org";
          license = prev.lib.licenses.gpl3Only;
          url = r: "https://download.kde.org/stable/krita/${r.version}/krita-${r.version}-signed.dmg";
        };
      }
    )
  ];
}
