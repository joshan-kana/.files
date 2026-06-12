{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dotfiles;
  primaryHome = "${cfg.users.primary.homeRoot}/${cfg.users.primary.name}";
  repoPath =
    if cfg.paths.repoPath != null then cfg.paths.repoPath else "${primaryHome}/${cfg.paths.repoName}";
in
{
  programs.nh = {
    enable = true;
    flake = repoPath;
  };

  programs.zsh.enable = true;
  programs.zsh.enableBashCompletion = true;
  users.defaultUserShell = pkgs.zsh;

  documentation = {
    enable = true;
    man = {
      enable = true;
      cache.enable = true;
    };
  };

  programs.direnv = {
    enable = true;
    silent = true;
    enableZshIntegration = false;
  };

  networking.networkmanager.enable = true;
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

  nixpkgs.config.allowUnfree = true;

  environment.sessionVariables = {
    DOTFILES = repoPath;
    FLK_PROFILE = cfg.profile.name;
    OLLAMA_URL = cfg.services.ollama.url;
    NIXOS_REBUILD_FLAGS = cfg.rebuild.flags;
  };

  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    lf
    lshw
    fastfetch
    home-manager
    tree
    glow
    htop
    nixfmt
  ];

  virtualisation.vmVariant.virtualisation = {
    cores = 4;
    memorySize = 8192;
  };

  nix.settings = {
    trusted-users = [
      "root"
      cfg.users.primary.name
    ];
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    warn-dirty = false;
    substituters = [
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHd59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
    require-sigs = true;
    fallback = false;
    builders-use-substitutes = true;
  };

  system.stateVersion = lib.mkDefault "23.05";
}
