{ lib, ... }:

let
  semantic = import ../lib/semantic-scopes.nix { inherit lib; };

  # This module-shaped let value is intentionally consumed by both evaluators.
  # nixd should therefore provide native option completion/hover inside it.
  sharedZshConfig = _: {
    programs.zsh = {
      enableCompletion = true;
    };
  };
in
semantic.systemModules {
  git = _: {
    programs.git.prompt.enable = true;

    home = _: {
      programs.git.settings.user.name = "Semantic Git";
    };
  };

  zsh = args: {
    programs.zsh = (sharedZshConfig args).programs.zsh;

    home = args: {
      programs.zsh = (sharedZshConfig args).programs.zsh;
    };
  };
}
