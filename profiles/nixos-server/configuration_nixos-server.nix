{
  config,
  lib,
  pkgs,
  dotfilesPath,
  profileName,
  nixosRebuildFlags,
  ...
}:

{
  networking.hostName = "nixos-server";
  networking.networkmanager.enable = true;
  networking.networkmanager.ensureProfiles.profiles."end0-static" = {
    connection = {
      id = "end0-static";
      type = "ethernet";
      interface-name = "end0";
      autoconnect = true;
    };
    ipv4 = {
      method = "manual";
      addresses1 = "192.168.1.3/24,192.168.1.1";
      dns = "192.168.1.2;192.168.1.1;1.1.1.1;";
    };
    ipv6.method = "auto";
  };
  time.timeZone = "Australia/Perth";

  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
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
    isNormalUser = true;
    description = "Joshan Kana";
    extraGroups = [
      "wheel"
      "networkmanager"
      "docker"
    ];
  };

  security.sudo.wheelNeedsPassword = true;
  services.openssh.enable = true;

  environment.sessionVariables = {
    DOTFILES = dotfilesPath;
    FLK_PROFILE = profileName;
    NIXOS_REBUILD_FLAGS = nixosRebuildFlags;
  };

  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    curl
    jq
    htop
    lshw
  ];

  virtualisation.vmVariant = {
    virtualisation = {
      cores = 4;
      memorySize = 8192;
    };
  };

  system.stateVersion = "25.05";
}
