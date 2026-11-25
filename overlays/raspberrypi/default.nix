{ inputs, ... }:
{
  nixpkgs.overlays = [
    (
      final: prev:
      prev.lib.optionalAttrs (prev.stdenv.hostPlatform.system == "aarch64-linux") {
        inherit (inputs.nixos-raspberrypi.packages.aarch64-linux) linuxPackages_rpi4;
        raspberrypifw-rpi4 = inputs.nixos-raspberrypi.packages.aarch64-linux.raspberrypifw;
        ffmpeg-rpi = inputs.nixos-raspberrypi.packages.aarch64-linux.ffmpeg_8;
        moonlight-qt-rpi = prev.moonlight-qt.override { ffmpeg = final.ffmpeg-rpi; };
        mpv-rpi = prev.mpv.override {
          mpv-unwrapped = final.mpv-unwrapped.override { ffmpeg = final.ffmpeg-rpi; };
        };
      }
    )
  ];
}
