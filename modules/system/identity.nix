{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dotfiles;
in
{
  networking.hostName = lib.mkDefault cfg.profile.name;

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.${cfg.users.primary.name} = { };
  users.users.${cfg.users.primary.name} = {
    isNormalUser = true;
    description = cfg.users.primary.fullName;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    packages = with pkgs; [ ];
    initialPassword = "test";
  };

  home =
    { lib, osConfig, ... }:
    let
      homeCfg = osConfig.dotfiles;
    in
    {
      home.username = homeCfg.users.primary.name;
      home.homeDirectory = lib.mkForce "${homeCfg.users.primary.homeRoot}/${homeCfg.users.primary.name}";
      programs.home-manager.enable = true;
      home.packages = [ ];
    };
}
