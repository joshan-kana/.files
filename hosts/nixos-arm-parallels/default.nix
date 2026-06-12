{ ... }:

{
  imports = [
    ../../modules/nixos/options/common.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/desktop-linux.nix
    ./home.nix
    ./hardware.nix
  ];

  dotfiles = {
    profile.name = "nixos-arm-parallels";
    features.desktop.enable = true;
    users.primary.homeRoot = "/home";
    paths.repoName = ".files";
    services.ollama.url = "http://localhost:11434/v1";
  };
}
