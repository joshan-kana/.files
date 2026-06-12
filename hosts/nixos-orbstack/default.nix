{ ... }:

{
  imports = [
    ../../modules/nixos/options/common.nix
    ../../modules/nixos/base.nix
    ../../overlays/monaspace-liga-overlay.nix
    ./container.nix
    ./host-env.nix
    ./home.nix
  ];

  networking.hostName = "nixos";

  dotfiles = {
    profile.name = "nixos-orbstack";
    users.primary.homeRoot = "/Users";
    paths.repoName = ".files";
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
