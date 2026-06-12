{ ... }:

{
  imports = [
    ../../modules/nixos/options/common.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/desktop-linux.nix
    ../../overlays/nvtop-overlay.nix
    ../../overlays/monaspace-liga-overlay.nix
    ./desktop.nix
    ./home.nix
    ./x86.nix
    ./hardware.nix
  ];

  dotfiles = {
    profile.name = "nixos";
    users.primary.homeRoot = "/home";
    paths.repoName = ".files";
    services.ollama.url = "http://localhost:11434/v1";
    rebuild.flags = "--impure";
  };
}
