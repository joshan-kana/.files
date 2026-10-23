{ inputs, ... }: {
  nixpkgs.overlays = [
    (final: _prev: {
      cosmic-noir-icons = final.callPackage ./package.nix { inherit inputs; };
    })
  ];
}
