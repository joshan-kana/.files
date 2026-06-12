{ config, inputs, ... }:

{
  imports = [
    ../../modules/nixos/options/common.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/desktop-linux.nix
    ../../overlays/nvtop-overlay.nix
    ./x86.nix
    ./hardware.nix
  ];

  home-manager.users.${config.dotfiles.users.primary.name}.imports = [
    inputs.plasma-manager.homeModules.plasma-manager
    inputs.spicetify-nix.homeManagerModules.default
    ../../modules/home/desktop-linux.nix
    ../../modules/home/x86-desktop.nix
    ../../desktop/plasma/plasma-hm.nix
    ../../desktop/hyprland/hyprland.nix
  ];

  dotfiles = {
    profile.name = "nixos";
    features.desktop.enable = true;
    rebuild.flags = "--impure";
  };
}
