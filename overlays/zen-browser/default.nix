{ inputs, ... }: {
  nixpkgs.overlays = [
    (final: _prev: {
      zen-browser-beta = inputs.zen-browser.packages.${final.stdenv.hostPlatform.system}.beta;
    })
  ];
}
