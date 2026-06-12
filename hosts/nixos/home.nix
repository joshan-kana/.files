{ config, inputs, ... }:

{
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.${config.dotfiles.users.primary.name}.imports = [
    inputs.plasma-manager.homeModules.plasma-manager
    inputs.spicetify-nix.homeManagerModules.default
    ../../modules/home/base.nix
    ../../modules/home/cli.nix
    ../../modules/home/desktop-linux.nix
    ../../modules/home/x86-desktop.nix
    ../../desktop/plasma/plasma_hm.nix
    ../../desktop/hyprland/hyprland.nix
  ];
}
