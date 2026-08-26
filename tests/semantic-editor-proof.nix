{ lib, ... }:
let
  semantic = import ../lib/semantic-scopes.nix { inherit lib; };
in
semantic.systemModules {
  git = _: {
    programs.git.prompt.enable = true;

    home = _: {
      programs.git.settings.user.name = "Semantic Git";
    };
  };
}
