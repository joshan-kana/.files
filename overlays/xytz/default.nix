{ inputs, ... }: {
  nixpkgs.overlays = [
    (final: _prev: {
      xytz = inputs.xytz.packages.${final.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          ../../patches/xytz/prefer-hls-streams.patch
          ../../patches/xytz/report-playback-failures.patch
        ];
      });
    })
  ];
}
