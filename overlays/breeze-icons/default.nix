_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
        breeze-camera-photo-fixed = prev.runCommand "breeze-camera-photo-fixed" { } ''
          install -Dm644 ${prev.kdePackages.breeze-icons}/share/icons/breeze/devices/64/camera-photo.svg "$out/share/icons/breeze/devices/64/camera-photo.svg"
          patch -d "$out/share/icons/breeze" -p2 < ${../../patches/breeze-icons/camera-photo-circles.patch}
        '';
      }
    )
  ];
}
