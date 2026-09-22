{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Root-only directory containing the bootstrap credentials used by backup jobs.
  backupCredentialsDir = "/var/lib/backup-credentials";

  # Collect generated `restic-<name>` wrapper commands so Zsh completion can be attached to them.
  resticWrapperCommands = lib.pipe config.services.restic.backups [
    (lib.filterAttrs (_: backup: backup.createWrapper))
    lib.attrNames
    (map (name: "restic-${name}"))
  ];
in
{
  environment.systemPackages = with pkgs; [
    restic
    rclone
  ];

  # Ensure the backup bootstrap directory exists and is accessible only to root.
  systemd.tmpfiles.rules = [
    "d ${backupCredentialsDir} 0700 root root - -"
  ];

  # Register Restic's completion function for every generated backup wrapper command.
  programs.zsh.interactiveShellInit =
    lib.mkIf (config.programs.zsh.enable && resticWrapperCommands != [ ])
      (
        lib.mkAfter ''
          autoload -Uz _restic
          compdef _restic ${lib.escapeShellArgs resticWrapperCommands}
        ''
      );

  secrets =
    {
      config,
      pkgs,
      ...
    }:

    let
      # Shared recovery-point policy used when pruning this host's repository.
      inherit (config.dotfiles.backups) retention;

      # Primary user whose local secret directory is protected by this backup.
      inherit (config.dotfiles.users) primary;

      # Runtime bootstrap inputs consumed by Restic/rclone; their contents stay outside Nix.
      backupRcloneConfig = "${backupCredentialsDir}/rclone.conf";
      backupPassword = "${backupCredentialsDir}/secrets-restic-password";

      # Give every host an independent encrypted repository under the shared remote.
      repository = "rclone:dropbox:Archives/Backups/secrets/${config.dotfiles.profile.name}";

      # Clear stale Restic locks before a scheduled backup starts.
      unlock = ''
        #!${pkgs.runtimeShell}
        ${pkgs.restic}/bin/restic unlock
      '';
    in
    {
      services.restic.backups = {
        secrets = {
          inherit repository;
          backupPrepareCommand = unlock;
          passwordFile = backupPassword;
          rcloneConfigFile = backupRcloneConfig;
          paths = [ config.dotfiles.secretsDir ];
          timerConfig = {
            OnCalendar = "*:0/15";
            Persistent = true;
            RandomizedDelaySec = "2m";
          };
        };

        secrets-maintenance = {
          inherit repository;
          passwordFile = backupPassword;
          rcloneConfigFile = backupRcloneConfig;
          paths = [ ];
          pruneOpts = [
            "--keep-within 1d"
            "--keep-hourly ${toString retention.hourly}"
            "--keep-daily ${toString retention.daily}"
            "--keep-weekly ${toString retention.weekly}"
            "--keep-monthly ${toString retention.monthly}"
          ];
          checkOpts = [ "--read-data" ];
          createWrapper = false;
          timerConfig = {
            OnCalendar = "daily";
            Persistent = true;
            RandomizedDelaySec = "1h";
          };
        };
      };

      # Ensure the primary-user secret directory exists with private user ownership and permissions.
      systemd.tmpfiles.rules = [
        "d ${config.dotfiles.secretsDir} 0700 ${primary.name} users - -"
      ];
    };
}
