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
  home-manager.users.${cfg.users.primary.name}.imports = [
    ../home/user.nix
  ];

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
}
