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
    ./options.nix
    ../../modules/nixos/base.nix
    ./networking.nix
    ./container-image-locking.nix
    ./apps
    ./storage.nix
    ./vm.nix
    ./image.nix
    ./hardware.nix
  ];

  dotfiles = {
    profile.name = "nixos-server";
    cli = {
      disabledPrograms = [
        "mpv"
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
      "http://nixos-server:8080/dotfiles"
    ];
    trusted-public-keys = lib.mkForce [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
      "dotfiles:U1NE7k5WM7I0l3losIw3VhG4eUGZAxsSvkw6br7p2iA="
    ];
  };

  users.users.${primaryUser} = {
    extraGroups = [ "docker" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGMZdbT05P/naiv07J32DxHDOR5A1z8F9jijeBrDkXWV joshankana@gmail.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4kCJGHE5VF6YL3Y2almpG/0cl7+h2mMrSRONRXIhZr Shortcuts on Joshan’s iPhone"
    ];
  };

  security.pam.sshAgentAuth = {
    enable = true;
    authorizedKeysFiles = [
      "/etc/sudo-authorized-key"
    ];
  };

  security.sudo = {
    extraConfig = ''
      Defaults:joshan noninteractive_auth
    '';
  };

  security.sudo.wheelNeedsPassword = true;

  systemd.tmpfiles.rules = [
    "f+ /etc/sudo-authorized-key 0444 root root - ${
      lib.concatStringsSep "\\n" [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIjtOri4c/7Nw3CMsv+ADMgepdVBTvtBlrTSJR+w5r7s joshan@nixos-server-sudo"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEp/T7PcjFts+DbMZnJrMle2UhBtWhJ2ycLYIlFMNkIu chatgpt-shell-sudo"
      ]
    }\\n"
  ];

  environment.systemPackages = with pkgs; [
    bluez
    curl
    jq
    rsync
  ];

  system.stateVersion = "25.05";
}
