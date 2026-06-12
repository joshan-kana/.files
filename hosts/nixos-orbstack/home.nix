{ config, ... }:

{
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.${config.dotfiles.users.primary.name}.imports = [
    ../../modules/home/base.nix
    ../../modules/home/cli.nix
  ];
}
