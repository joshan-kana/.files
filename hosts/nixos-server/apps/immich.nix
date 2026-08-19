{
  config,
  lib,
  pkgs,
  ...
}:

let
  storage = config.dotfiles.server.storage;
  appDataRoot = storage.appData.root;
  dataRoot = storage.dataRoot.path;
  dataGroup = storage.dataRoot.group.name;
  poolName = storage.dataRoot.poolName;
  postgresDataRoot = "${appDataRoot}/postgresql";
  postgresDataDir = "${postgresDataRoot}/${config.services.postgresql.package.psqlSchema}";
  databaseBackupDir = "${appDataRoot}/immich/database-backups";
  mediaRoot = "${dataRoot}/photos/immich";
  externalLibrary = "${dataRoot}/media-library";
in
{
  services.immich = {
    enable = true;
    openFirewall = true;
    mediaLocation = mediaRoot;
    machine-learning.enable = true;
  };

  # Immich's native module owns the PostgreSQL instance it uses. Keep the live
  # cluster under appDataRoot for local snapshots, but back up a logical dump
  # offsite instead of relying on restic to copy a running PostgreSQL cluster.
  services.postgresql.dataDir = postgresDataDir;
  services.postgresqlBackup = {
    enable = true;
    backupAll = false;
    databases = [ config.services.immich.database.name ];
    location = databaseBackupDir;
    pgdumpOptions = "--clean --if-exists";
  };
  services.restic.backups.apps.exclude = [ postgresDataRoot ];

  systemd.tmpfiles.rules = [
    "d ${appDataRoot}/immich 0750 postgres postgres - -"
    "d ${postgresDataRoot} 0750 postgres postgres - -"
    "d ${postgresDataDir} 0700 postgres postgres - -"
    "a+ ${appDataRoot} - - - - mask::rwx,u:postgres:x"
  ];

  # Do not create Vault paths during the generic tmpfiles phase: the ZFS pool
  # may not be mounted yet. Prepare them only after systemd has required the
  # Vault mount, then let the native Immich unit start.
  systemd.services.immich-vault-storage = {
    description = "Prepare Vault storage for Immich";
    before = [ "immich-server.service" ];
    unitConfig.RequiresMountsFor = [ dataRoot ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      mount_source="$(${pkgs.util-linux}/bin/findmnt -n -o SOURCE --target ${lib.escapeShellArg dataRoot} || true)"
      mount_type="$(${pkgs.util-linux}/bin/findmnt -n -o FSTYPE --target ${lib.escapeShellArg dataRoot} || true)"
      expected_source=${lib.escapeShellArg "${poolName}/data"}

      if [ "$mount_type" != "zfs" ] || [ "$mount_source" != "$expected_source" ]; then
        echo "Refusing to prepare Immich storage: ${dataRoot} is not mounted from ${poolName}/data." >&2
        echo "Detected source: ''${mount_source:-none}; filesystem: ''${mount_type:-none}" >&2
        exit 1
      fi

      ${pkgs.coreutils}/bin/install -d \
        -m 2775 \
        -o root \
        -g ${lib.escapeShellArg dataGroup} \
        ${lib.escapeShellArg "${dataRoot}/photos"}

      ${pkgs.coreutils}/bin/install -d \
        -m 2770 \
        -o immich \
        -g ${lib.escapeShellArg dataGroup} \
        ${lib.escapeShellArg mediaRoot}

      if [ ! -d ${lib.escapeShellArg externalLibrary} ]; then
        echo "Immich external library is missing: ${externalLibrary}" >&2
        exit 1
      fi
    '';
  };

  systemd.services.immich-server = {
    requires = [ "immich-vault-storage.service" ];
    after = [ "immich-vault-storage.service" ];
    unitConfig.RequiresMountsFor = [ dataRoot ];
    serviceConfig = {
      SupplementaryGroups = [ dataGroup ];
      BindReadOnlyPaths = [ externalLibrary ];
    };
  };
}
