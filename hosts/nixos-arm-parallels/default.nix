{ pkgs, ... }:

{
  imports = [ ../../modules/options ];

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernelPackages = pkgs.linuxPackages_latest;
    plymouth.enable = false;
  };

  system = import ../../modules/system;
  nix = import ../../modules/nix.nix;
  theme = import ../../modules/theme;
  cli = import ../../modules/cli.nix;
  networking = import ../../modules/networking.nix;
  appimage = import ../../modules/appimage.nix;
  ssh = import ../../modules/ssh.nix;
  audio = import ../../modules/audio.nix;
  virtualisation = import ../../modules/virtualisation;
  apps = import ../../modules/apps.nix;
  desktop = import ../../modules/desktop;
  hardware = import ./hardware.nix;

  dotfiles.profile.name = "nixos-arm-parallels";
}
