{ lib, osConfig, ... }:

let
  cfg = osConfig.dotfiles;
  primaryHome = "${cfg.users.primary.homeRoot}/${cfg.users.primary.name}";
in
{
  home.username = cfg.users.primary.name;
  home.homeDirectory = lib.mkForce primaryHome;

  programs.home-manager.enable = true;
  home.packages = [ ];
}
