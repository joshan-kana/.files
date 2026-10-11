{ configuration }:

let
  inherit (configuration) config;
  primary = config.dotfiles.users.primary.name;
  home = config.home-manager.users.${primary};
  scopes = config.dotfiles.resolvedScopes;
in
assert config.nix.enable == false;
assert config.dotfiles.users.primary.homeRoot == "/Users";
assert scopes.cli.zsh.enable;
assert scopes.cli.nixShell.enable;
assert scopes.desktop.hammerspoon.enable;
assert scopes.desktop.yabai.enable;
assert home.programs.zsh.enable;
assert home.programs.zellij.enable;
assert home.home.file ? ".hammerspoon/stylix_palette.lua";
assert home.xdg.configFile ? "yabai/yabairc";
true
