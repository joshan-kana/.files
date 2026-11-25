{ inputs, ... }:
{
  nixpkgs.overlays = [
    (
      final: prev:
      prev.lib.optionalAttrs (prev.stdenv.hostPlatform.system == "aarch64-linux") {
        inherit (inputs.nixos-raspberrypi.packages.aarch64-linux) linuxPackages_rpi4;
        raspberrypifw-rpi4 = inputs.nixos-raspberrypi.packages.aarch64-linux.raspberrypifw;
        ffmpeg-rpi = inputs.nixos-raspberrypi.packages.aarch64-linux.ffmpeg_8;
        kodi-gbm-rpi =
          let
            rpi = inputs.nixos-raspberrypi.legacyPackages.aarch64-linux;
            kodi = rpi.kodi-gbm.withPackages (addons: [ addons.jellyfin ]);
          in
          prev.symlinkJoin {
            name = "kodi-gbm-rpi";
            paths = [ kodi ];
            nativeBuildInputs = [ prev.makeWrapper ];
            postBuild = ''
              for program in kodi kodi-standalone; do
                wrapProgram "$out/bin/$program" \
                  --set GBM_BACKENDS_PATH "${rpi.mesa}/lib/gbm" \
                  --set LIBGL_DRIVERS_PATH "${rpi.mesa}/lib/dri" \
                  --set __EGL_VENDOR_LIBRARY_FILENAMES "${rpi.mesa}/share/glvnd/egl_vendor.d/50_mesa.json"
              done
            '';
            meta = kodi.meta // {
              mainProgram = "kodi";
            };
          };
        moonlight-qt-rpi = prev.moonlight-qt.override { ffmpeg = final.ffmpeg-rpi; };
        mpv-rpi = prev.mpv.override {
          mpv-unwrapped = final.mpv-unwrapped.override { ffmpeg = final.ffmpeg-rpi; };
        };
      }
    )
  ];
}
