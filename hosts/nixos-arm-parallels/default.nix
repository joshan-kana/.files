{ lib, pkgs, ... }:

let
  modules = import ../../modules;
  profiles = modules.profiles { inherit lib; };
in
{
  imports = [
    profiles.desktop.arm
  ];

  dotfiles.profile.name = "nixos-arm-parallels";

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernelPackages = pkgs.linuxPackages_latest;
    plymouth.enable = false;
  };

  inherit (modules)
    system
    nix
    theme
    cli
    networking
    appimage
    ssh
    audio
    virtualisation
    desktopApps
    desktop
    ;
  hardware = import ./hardware.nix;

}
