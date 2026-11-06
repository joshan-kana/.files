_: {
  nixpkgs.overlays = [
    (final: _prev: {
      xytz =
        (final.callPackage
          "${(builtins.getFlake "github:xdagiz/xytz/d2415bb337ea96f28996f505be0bae74b7c16e31").outPath}/nix/package.nix"
          { }
        ).overrideAttrs
          (old: {
            patches = (old.patches or [ ]) ++ [
              ../../patches/xytz/prefer-hls-streams.patch
              ../../patches/xytz/report-playback-failures.patch
            ];
            passthru = (old.passthru or { }) // {
              autoUpdate = false;
            };
          });
    })
  ];
}
