_: {
  nixpkgs.overlays = [
    (_final: prev: {
      ncmpcpp = prev.ncmpcpp.override { visualizerSupport = true; };
    })
  ];
}
