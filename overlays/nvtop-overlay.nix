{ config, pkgs, ... }:
{
  nixpkgs.overlays = [
    (final: prev: {
      nvtopPackages = prev.nvtopPackages // {
        full = prev.nvtopPackages.nvidia;  # or whichever variant you need
      };
    })
  ];
}