_: {
  nixpkgs.overlays = [
    (
      final: prev:
      prev.lib.optionalAttrs (prev.stdenv.hostPlatform.system == "aarch64-linux") {
        moonlight-qt-rpi = prev.moonlight-qt.override { ffmpeg = final.raspberrypi.ffmpeg_8; };
      }
    )
  ];
}
