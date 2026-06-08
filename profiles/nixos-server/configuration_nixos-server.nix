{
  config,
  lib,
  pkgs,
  dotfilesPath,
  profileName,
  nixosRebuildFlags,
  ...
}:

let
  cleanupRetentionDays = 7;
  cleanupSchedule = "weekly";
  minFree = "2G";
in
{
  networking.hostName = "nixos-server";
  networking.networkmanager.enable = true;
  networking.networkmanager.unmanaged = [
    "interface-name:adguard-shim"
  ];
  networking.networkmanager.ensureProfiles.profiles."wired-static" = {
    connection = {
      id = "wired-static";
      type = "ethernet";
      "interface-name" = "end0";
      autoconnect = true;
      "autoconnect-priority" = 100;
    };
    ipv4 = {
      method = "manual";
      address1 = "192.168.1.3/24,192.168.1.1";
      dns = "192.168.1.2;192.168.1.1;1.1.1.1;";
      "ignore-auto-dns" = true;
    };
    ipv6 = {
      method = "auto";
      "ignore-auto-dns" = true;
    };
  };
  time.timeZone = "Australia/Perth";

  nixpkgs.config.allowUnfree = true;

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

  services.snapper.configs.apps = {
    FREE_LIMIT = minFree;
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    min-free = minFree;
    warn-dirty = false;
    trusted-users = [
      "root"
      "joshan"
    ];
    substituters = lib.mkForce [
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
      "https://nixos-raspberrypi.cachix.org"
    ];
    trusted-public-keys = lib.mkForce [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
    require-sigs = true;
    fallback = false;
    builders-use-substitutes = true;
  };

  programs.nh = {
    enable = true;
    flake = dotfilesPath;
  };

  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  users.users.joshan = {
    initialPassword = "test";
    isNormalUser = true;
    description = "Joshan Kana";
    extraGroups = [
      "wheel"
      "networkmanager"
      "docker"
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGMZdbT05P/naiv07J32DxHDOR5A1z8F9jijeBrDkXWV joshankana@gmail.com"
    ];
  };

  security.sudo.wheelNeedsPassword = true;
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };
  services.tailscale = {
    useRoutingFeatures = "server";
    extraUpFlags = [ "--advertise-routes=192.168.1.0/24" ];
    extraSetFlags = [ "--hostname=nixos-server" ];
  };

  environment.sessionVariables = {
    DOTFILES = dotfilesPath;
    FLK_PROFILE = profileName;
    NIXOS_REBUILD_FLAGS = nixosRebuildFlags;
  };

  environment.systemPackages = with pkgs; [
    bluez
    git
    vim
    wget
    curl
    jq
    htop
    lshw
    rsync
  ];

  virtualisation.vmVariant = {
    virtualisation = {
      cores = 4;
      memorySize = 8192;
    };
  };

  system.stateVersion = "25.05";
}
