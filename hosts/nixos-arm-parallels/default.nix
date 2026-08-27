{ lib, pkgs, ... }:

let
  profiles = import ../../modules/profiles { inherit lib; };
in
{
  imports = [
    ../../modules/options
    profiles.desktop.arm
  ];

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernelPackages = pkgs.linuxPackages_latest;
    plymouth.enable = false;
  };

  system = import ../../modules/system;
  nix = import ../../modules/nix;
  theme = import ../../modules/theme;
  cli = import ../../modules/cli;
  networking = import ../../modules/networking;
  appimage = import ../../modules/appimage;
  ssh = import ../../modules/ssh;
  audio = import ../../modules/audio;
  virtualisation = import ../../modules/virtualisation;
  desktopApps = import ../../modules/desktop-apps;
  desktop = import ../../modules/desktop;
  hardware = import ./hardware.nix;

  dotfiles.profile.name = "nixos-arm-parallels";
}
