_: {
  nixpkgs.overlays = [
    (_final: prev: {
      ncmpcpp = (prev.ncmpcpp.override { visualizerSupport = true; }).overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ../../patches/ncmpcpp/libcxx22-transform-iterator.patch ];
        passthru = (old.passthru or { }) // {
          autoUpdate = false;
        };
      });
    })
  ];
}
