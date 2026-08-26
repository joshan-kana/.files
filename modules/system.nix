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
    ./home/user.nix
  ];

  documentation = {
    enable = true;
    man = {
      enable = true;
      cache.enable = true;
    };
  };

  time.timeZone = "Australia/Perth";
  i18n.defaultLocale = "en_GB.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_AU.UTF-8";
    LC_IDENTIFICATION = "en_AU.UTF-8";
    LC_MEASUREMENT = "en_AU.UTF-8";
    LC_MONETARY = "en_AU.UTF-8";
    LC_NAME = "en_AU.UTF-8";
    LC_NUMERIC = "en_AU.UTF-8";
    LC_PAPER = "en_AU.UTF-8";
    LC_TELEPHONE = "en_AU.UTF-8";
    LC_TIME = "en_AU.UTF-8";
  };

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

  system.stateVersion = lib.mkDefault "23.05";
}
