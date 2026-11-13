_: {
  nixpkgs.overlays = [
    (_final: prev: {
      # Remove once nixpkgs includes NixOS/nixpkgs@ff38fcd60975.
      cargo-bundle = prev.cargo-bundle.overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.pkg-config ];
        buildInputs = (old.buildInputs or [ ]) ++ [ prev.aws-lc ];
      });
    })
  ];
}
