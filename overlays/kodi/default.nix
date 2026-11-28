{ inputs, ... }:
{
  nixpkgs.overlays = [
    (
      final: prev:
      prev.lib.optionalAttrs (prev.stdenv.hostPlatform.system == "aarch64-linux") {
        kodi-gbm-rpi =
          let
            rpi = inputs.nixos-raspberrypi.legacyPackages.aarch64-linux;
            kodi = final.raspberrypi.kodi-gbm.withPackages (addons: [ addons.jellyfin ]);
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
      }
    )
  ];
}
