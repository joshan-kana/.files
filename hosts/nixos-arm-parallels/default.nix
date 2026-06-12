{ config, inputs, ... }:

{
  imports = [
    ../../modules/nixos/options/common.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/desktop-linux.nix
    ./hardware.nix
  ];

  home-manager.users.${config.dotfiles.users.primary.name}.imports = [
    inputs.plasma-manager.homeModules.plasma-manager
    ../../modules/home/desktop-linux.nix
    ../../desktop/plasma/plasma-hm.nix
    ../../desktop/hyprland/hyprland.nix
  ];

  dotfiles = {
    profile.name = "nixos-arm-parallels";
    features.desktop.enable = true;
  };
}
