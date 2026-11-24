{
  config,
  lib,
  system,
  ...
}:

let
  inherit (config.dotfiles.users) primary;
  inherit (lib.systems.elaborate system) isDarwin isLinux;
in
{
  networking.hostName = lib.mkDefault config.dotfiles.profile.name;

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.${primary.name} = { };
}
// lib.optionalAttrs isLinux {
  users.users.${primary.name} = {
    isNormalUser = true;
    description = primary.fullName;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };
}
// lib.optionalAttrs isDarwin {
  system.primaryUser = primary.name;
  users.users.${primary.name}.home = "${primary.homeRoot}/${primary.name}";
}
// {
  home = _: {
    home.username = primary.name;
    home.homeDirectory = lib.mkForce "${primary.homeRoot}/${primary.name}";
    programs.home-manager.enable = true;
  };
}
