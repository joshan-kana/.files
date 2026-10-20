{ inputs, ... }:
{
  nixpkgs.overlays = [
    (final: _prev: {
      configarr = inputs.configarr.packages.${final.stdenv.hostPlatform.system}.default;
    })
  ];
}
