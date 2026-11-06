{ inputs, ... }: {
  nixpkgs.overlays = [
    (final: _prev: {
      xytz = inputs.xytz.packages.${final.stdenv.hostPlatform.system}.default;
    })
  ];
}
