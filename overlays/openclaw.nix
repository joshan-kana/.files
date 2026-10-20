{ inputs, ... }: {
  nixpkgs.overlays = [
    (final: _prev: {
      openclaw-gateway =
        inputs.nix-openclaw.packages.${final.stdenv.hostPlatform.system}.openclaw-gateway;
    })
  ];
}
