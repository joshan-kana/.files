_: {
  nixpkgs.overlays = [
    (_final: prev: {
      ncmpcpp = (prev.ncmpcpp.override { visualizerSupport = true; }).overrideAttrs (old: {
        passthru = (old.passthru or { }) // {
          autoUpdate = false;
        };
      });
    })
  ];
}
