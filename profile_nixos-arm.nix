{ config, ... }:
{
  environment.sessionVariables = {
    # Setting path for dotfiles directory
    DOTFILES = "/home/joshan/.files";

    # Settings flake profile
    FLK_PROFILE = "nixos-arm";
  };
}
