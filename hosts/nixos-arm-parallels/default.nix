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

  compatibility = { lib, ... }: {
    # Preserve pre-refactor evaluator ownership while shared modules expose
    # both native NixOS and Home Manager configurations. Remove selectively
    # in post-merge behavior changes when enabling the new side is desired.
    programs = {
      lazygit.enable = lib.mkForce false;
      starship.enable = lib.mkForce false;
      neovim.enable = lib.mkForce false;
    };

    home = { lib, ... }: {
      programs = {
        nh.enable = lib.mkForce false;
        direnv.enable = lib.mkForce false;
      };
    };
  };

  dotfiles.profile.name = "nixos-arm-parallels";
}
