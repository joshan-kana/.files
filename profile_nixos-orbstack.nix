{ config, ... }:
{
  environment.sessionVariables = {
    # Setting path for dotfiles directory
    DOTFILES = "/Users/joshan/.files";

    # Settings flake profile
    FLK_PROFILE = "nixos-orbstack";
  };
}
