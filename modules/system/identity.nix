{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config) dotfiles;
  inherit (dotfiles.users) primary;
in
{
  networking.hostName = lib.mkDefault dotfiles.profile.name;

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.${primary.name} = { };
  users.users.${primary.name} = {
    isNormalUser = true;
    description = primary.fullName;
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
      inherit (osConfig) dotfiles;
      inherit (dotfiles.users) primary;
    in
    {
      home.username = primary.name;
      home.homeDirectory = lib.mkForce "${primary.homeRoot}/${primary.name}";
      programs.home-manager.enable = true;
      home.packages = [ ];
    };
}
