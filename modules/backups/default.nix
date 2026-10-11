{
  lib,
  pkgs,
  system,
  ...
}:

let
  inherit (lib.systems.elaborate system) isDarwin isLinux;
  # Root-only directory containing the bootstrap credentials used by backup jobs.
  backupCredentialsDir = "/var/lib/backup-credentials";

  # Collect generated `restic-<name>` wrapper commands so Zsh completion can be attached to them.
  resticWrapperCommandsFor =
    backups:
    lib.pipe backups [
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

  config = lib.optionalAttrs isLinux {
    # Ensure the backup bootstrap directory exists and is accessible only to root.
    systemd.tmpfiles.rules = [
      "d ${backupCredentialsDir} 0700 root root - -"
    ];
  };

  home =
    {
      config,
      lib,
      osConfig,
      ...
    }:

    let
      resticWrapperCommands =
        if isLinux then resticWrapperCommandsFor osConfig.services.restic.backups else [ ];
    in
    {
      # Register Restic wrapper completions after Home Manager initializes Zsh completion.
      programs.zsh.initContent = lib.mkIf (config.programs.zsh.enable && resticWrapperCommands != [ ]) (
        lib.mkAfter ''
          autoload -Uz _restic
          compdef _restic ${lib.escapeShellArgs resticWrapperCommands}
        ''
      );
    };

  secrets =
    {
      config,
      lib,
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
      macCredentialsDir = "${primary.homeRoot}/${primary.name}/Library/Application Support/SecretsBackup";
      macBackup = pkgs.writeShellApplication {
        name = "secrets-backup";
        runtimeInputs = with pkgs; [
          restic
          rclone
        ];
        text = ''
          export RCLONE_CONFIG=${lib.escapeShellArg "${macCredentialsDir}/rclone.conf"}
          export RESTIC_PASSWORD_FILE=${lib.escapeShellArg "${macCredentialsDir}/secrets-restic-password"}
          export RESTIC_REPOSITORY=${lib.escapeShellArg repository}
          case "''${1:-backup}" in
            backup)
              restic unlock
              exec restic backup --quiet ${lib.escapeShellArg config.dotfiles.secretsDir}
              ;;
            maintenance)
              restic forget --quiet --prune --keep-within 1d \
                --keep-hourly ${toString retention.hourly} \
                --keep-daily ${toString retention.daily} \
                --keep-weekly ${toString retention.weekly} \
                --keep-monthly ${toString retention.monthly}
              exec restic check --quiet --read-data
              ;;
            *) echo "usage: secrets-backup {backup|maintenance}" >&2; exit 2 ;;
          esac
        '';
      };
    in
    {
      home =
        _:
        lib.optionalAttrs isDarwin {
          home.packages = [ macBackup ];
          launchd.agents = {
            secrets-backup = {
              enable = true;
              config = {
                Label = "com.joshankana.secrets-backup";
                ProgramArguments = [
                  "${lib.getExe macBackup}"
                  "backup"
                ];
                StartInterval = 900;
                RunAtLoad = true;
              };
            };
            secrets-backup-maintenance = {
              enable = true;
              config = {
                Label = "com.joshankana.secrets-backup-maintenance";
                ProgramArguments = [
                  "${lib.getExe macBackup}"
                  "maintenance"
                ];
                StartCalendarInterval = {
                  Hour = 3;
                  Minute = 30;
                };
              };
            };
          };
        };
    }
    // lib.optionalAttrs isLinux {
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
