_: {
  nixpkgs.overlays = [
    (
      final: prev:
      prev.lib.optionalAttrs (prev.stdenv.hostPlatform.system == "aarch64-linux") {
        mpv-rpi = prev.mpv.override {
          mpv-unwrapped = final.mpv-unwrapped.override { ffmpeg = final.raspberrypi.ffmpeg_8; };
        };
      }
    )
  ];
}
