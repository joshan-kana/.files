{ config, lib, ... }:

let
  resticWrapperCommands = lib.pipe config.services.restic.backups [
    (lib.filterAttrs (_: backup: backup.createWrapper))
    lib.attrNames
    (map (name: "restic-${name}"))
  ];
in
{
  config = lib.mkIf (config.programs.zsh.enable && resticWrapperCommands != [ ]) {
    programs.zsh.interactiveShellInit = lib.mkAfter ''
      autoload -Uz _restic
      compdef _restic ${lib.escapeShellArgs resticWrapperCommands}
    '';
  };
}
