_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs (builtins.elem prev.stdenv.hostPlatform.system prev.lib.platforms.darwin) {
        vlc = import ../../lib/cask-app.nix { inherit prev; } {
          cask = "vlc";
          release = {
            version = "3.0.24";
            hashes = {
              aarch64-darwin = "sha256-ZKidk83TCw6XExdD4kY3PbgtaCbqiC0mXUbXSxNtorc=";
              x86_64-darwin = "sha256-HvbJA+LcAm1OWN33sqntDrb4yvgKmp9G+WSQNAuWJwc=";
            };
          };
          pname = "vlc";
          appName = "VLC.app";
          homepage = "https://www.videolan.org/vlc";
          license = prev.lib.licenses.gpl2Plus;
          url =
            r:
            "https://get.videolan.org/vlc/${r.version}/macosx/vlc-${r.version}-${
              if prev.stdenv.hostPlatform.isAarch64 then "arm64" else "intel64"
            }.dmg";
        };
      }
    )
  ];
}
