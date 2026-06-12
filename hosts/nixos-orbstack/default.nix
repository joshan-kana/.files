{ ... }:

{
  imports = [
    ../../modules/nixos/options/common.nix
    ../../modules/nixos/base.nix
    ./orbstack-generated.nix
    ./container.nix
    ./host-env.nix
  ];

  dotfiles = {
    profile.name = "nixos-orbstack";
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
