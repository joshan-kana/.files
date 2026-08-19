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
  postgresDataDir = "${appDataRoot}/postgresql/${config.services.postgresql.package.psqlSchema}";
  mediaRoot = "${dataRoot}/photos/immich";
  externalLibrary = "${dataRoot}/media-library";
in
{
  services.immich = {
    enable = true;
    host = "0.0.0.0";
    port = 2283;
    openFirewall = true;
    mediaLocation = mediaRoot;

    # The Pi can still generate thumbnails in the server process, but the
    # separate ML worker is intentionally disabled until its cost on this host
    # has been measured.
    machine-learning.enable = false;
  };

  # Immich's native module owns the PostgreSQL instance it uses. Keep that
  # database state inside the normal app-data snapshot and offsite-backup root.
  services.postgresql.dataDir = postgresDataDir;

  # Vault is group-readable collaborative storage. Membership gives Immich
  # read access to the existing external library without copying those files
  # into its managed media tree.
  users.users.immich.extraGroups = [ dataGroup ];

  systemd.tmpfiles.rules = [
    "d ${appDataRoot}/postgresql 0750 postgres postgres - -"
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
  };
}
