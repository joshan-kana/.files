{ config, pkgs, ... }:

{
  nixpkgs.overlays = (import ../../overlays/bottles.nix { }).nixpkgs.overlays;

  virtualisation.docker.enable = true;
  users.users.${config.dotfiles.users.primary.name}.extraGroups = [
    "docker"
    "libvirtd"
  ];

  virtualisation.libvirtd = {
    enable = true;
    qemu.swtpm.enable = true;
  };
  programs.virt-manager.enable = true;

  environment.systemPackages = with pkgs; [
    quickemu
    distrobox
    bottles
  ];
}
