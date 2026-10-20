{ inputs, ... }: {
  nixpkgs.overlays = [
    (final: _prev: {
      determinate-nix-cli = inputs.determinate-nix.packages.${final.stdenv.hostPlatform.system}.nix-cli;
      determinate-nix-manpages =
        inputs.determinate-nix.packages.${final.stdenv.hostPlatform.system}.nix-manual-manpages-only;
    })
  ];
}
