{
  config,
  pkgs,
  dotfilesPath,
  profileName,
  nixosRebuildFlags,
  ...
}:

{
  networking.hostName = "nixos-server";
  networking.networkmanager.enable = true;
  time.timeZone = "Australia/Perth";

  nixpkgs.config.allowUnfree = true;

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
