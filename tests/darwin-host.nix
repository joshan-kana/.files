{ configuration }:

let
  inherit (configuration) config;
  primary = config.dotfiles.users.primary.name;
  home = config.home-manager.users.${primary};
  scopes = config.dotfiles.resolvedScopes;
in
assert config.nix.enable == false;
assert builtins.elem "http://nixos-server.home:8080/dotfiles"
  config.determinateNix.customSettings.extra-substituters;
assert config.determinateNix.customSettings.builders-use-substitutes;
assert config.services.comin.enable;
assert config.services.comin.allowForcePush;
assert config.launchd.daemons ? comin;
assert config.launchd.daemons ? comin-event-listener;
assert home.launchd.agents ? attic-watch-store;
assert home.launchd.agents ? secrets-backup;
assert home.launchd.agents ? secrets-backup-maintenance;
assert builtins.all (name: scopes.${name}.enable) [
  "system"
  "nix"
  "cli"
  "networking"
  "theme"
  "backups"
  "audio"
  "virtualisation"
  "desktop"
  "desktopApps"
  "appimage"
];
assert config.dotfiles.users.primary.homeRoot == "/Users";
assert scopes.cli.zsh.enable;
assert scopes.cli.nixShell.enable;
assert scopes.cli.systemCommands.enable;
assert scopes.cli.systemCommands.vm.enable;
assert scopes.desktopApps.vscode.enable;
assert scopes.networking.ssh.enable;
assert scopes.desktop.hammerspoon.enable;
assert scopes.desktop.yabai.enable;
assert home.programs.zsh.enable;
assert home.programs.zellij.enable;
assert builtins.match ".*nh darwin.*" home.home.shellAliases.sup != null;
assert home.home.file ? ".hammerspoon/stylix_palette.lua";
assert home.xdg.configFile ? "yabai/yabairc";
true
