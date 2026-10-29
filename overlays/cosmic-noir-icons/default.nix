_: {
  nixpkgs.overlays = [
    (final: _prev: {
      cosmic-noir-icons = final.callPackage ./package.nix { };
    })
  ];
}
