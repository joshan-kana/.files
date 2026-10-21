{
  config,
  lib,
  pkgs,
  system,
  ...
}:

let
  inherit (config.dotfiles.users) primary;
  inherit (lib.systems.elaborate system) isDarwin isLinux;
in
{
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.${primary.name} = { };
}
// lib.optionalAttrs isLinux {
  networking.hostName = lib.mkDefault config.dotfiles.profile.name;

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
}
// lib.optionalAttrs isDarwin {
  networking.hostName = lib.mkDefault config.dotfiles.profile.name;
  system.primaryUser = primary.name;
  users.users.${primary.name}.home = "${primary.homeRoot}/${primary.name}";
}
// {
  home = _: {
    home.username = primary.name;
    home.homeDirectory = lib.mkForce "${primary.homeRoot}/${primary.name}";
    programs.home-manager.enable = true;
    home.packages = [ ];
  };
}
