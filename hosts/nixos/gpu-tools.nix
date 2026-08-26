{ pkgs, ... }:

{
  nixpkgs.overlays = (import ../../overlays/nvtop-overlay.nix { }).nixpkgs.overlays;

  environment.systemPackages = with pkgs; [
    nvtopPackages.full
    intel-gpu-tools
  ];
}
