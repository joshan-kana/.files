{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  primaryUser = config.dotfiles.users.primary.name;
  cleanupRetentionDays = 7;
  cleanupSchedule = "weekly";
  minFree = "2G";
in
{
  imports = [
    inputs.nixos-hardware.nixosModules.raspberry-pi-4
    ../../modules/nixos/options/common.nix
    ../../modules/nixos/options/server.nix
    ../../modules/nixos/base.nix
    ./networking.nix
    ./apps.nix
    ./image.nix
    ./hardware.nix
  ];

  dotfiles = {
    profile.name = "nixos-server";
    server.appDataRoot = "/var/lib/apps";
    server.secretsDir = "/root/secrets";
    cli = {
      disabledPrograms = [
        "mpv"
        "zellij"
        "tmuxai"
      ];
      disabledAliases = [
        "h"
        "HI"
        "HN"
        "k"
        "cpd"
        "p"
        "sysvm"
        "svm"
        "ollama"
      ];
    };
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  nix.gc = {
    automatic = true;
    dates = cleanupSchedule;
    options = "--delete-older-than ${toString cleanupRetentionDays}d";
  };

  nix.optimise = {
    automatic = true;
    dates = [ cleanupSchedule ];
  };

  services.journald.extraConfig = ''
    SystemMaxUse=1G
    SystemKeepFree=${minFree}
    MaxRetentionSec=${toString cleanupRetentionDays}day
  '';

  virtualisation.docker.autoPrune = {
    enable = true;
    dates = cleanupSchedule;
    flags = [
      "--all"
      "--filter=until=${toString (cleanupRetentionDays * 24)}h"
    ];
  };

  services.snapper.configs.apps.FREE_LIMIT = minFree;

  nix.settings = {
    min-free = minFree;
    substituters = lib.mkForce [
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
      "https://nixos-raspberrypi.cachix.org"
    ];
    trusted-public-keys = lib.mkForce [
      "cache.nixos.org-1:6NCHd59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  users.users.${primaryUser}.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGMZdbT05P/naiv07J32DxHDOR5A1z8F9jijeBrDkXWV joshankana@gmail.com"
  ];

  security.sudo.wheelNeedsPassword = true;

  environment.systemPackages = with pkgs; [
    bluez
    curl
    jq
    rsync
  ];

  system.stateVersion = "25.05";
}
