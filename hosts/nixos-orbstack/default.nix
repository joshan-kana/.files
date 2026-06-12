{ config, ... }:

{
  imports = [
    ../../modules/nixos/options/common.nix
    ../../modules/nixos/base.nix
    ./orbstack-generated.nix
    ./container.nix
    ./host-env.nix
  ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.${config.dotfiles.users.primary.name}.imports = [
    ../../modules/home/base.nix
    ../../modules/home/theme.nix
    ../../modules/home/cli.nix
  ];

  dotfiles = {
    profile.name = "nixos-orbstack";
    users.primary.homeRoot = "/home";
    paths.repoPath = "/Users/joshan/.files";
    services.ollama.url = "http://host.orb.internal:11434/v1";
    rebuild.flags = "--impure";
    cli = {
      aliasOverrides.cpd = ''printf "%s" "$(pwd | tr -d "\n")" | pbcopy && echo "Copied path to macOS clipboard"'';
      disabledAliases = [
        "h"
        "HI"
        "HN"
        "k"
      ];
    };
  };
}
