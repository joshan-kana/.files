{ config, lib, ... }:

let
  inherit (config.dotfiles) server;
  inherit (server.storage) appData dataRoot;
  dataDir = "${appData.root}/paperless";
in
{
  services.paperless = {
    enable = true;
    address = server.lan.serverIp;
    inherit dataDir;
    mediaDir = "${dataRoot.path}/paperless/media";
    consumptionDir = "${dataRoot.path}/paperless/consume";
    database.createLocally = true;
    configureTika = true;

    settings = {
      PAPERLESS_CONSUMER_RECURSIVE = true;
      PAPERLESS_CONSUMER_SUBDIRS_AS_TAGS = true;
      PAPERLESS_FILENAME_FORMAT = "{{ created_year }}/{{ correspondent }}/{{ title }}";
      PAPERLESS_FILENAME_FORMAT_REMOVE_NONE = true;
    };
  };

  users.users = lib.mkIf config.services.paperless.enable {
    ${config.services.paperless.user}.extraGroups = [ appData.group.name ];
  };

  services.postgresqlBackup = lib.mkIf config.services.paperless.enable {
    enable = true;
    databases = [ "paperless" ];
    location = "${dataDir}/backups";
    startAt = "*:0/${toString server.storage.snapshots.intervalMinutes}";
  };

  systemd.tmpfiles.settings."11-paperless-postgresql-backup-access" =
    lib.mkIf config.services.paperless.enable
      {
        "${appData.root}"."a+".argument = "u:postgres:--x";
        "${dataDir}"."a+".argument = "u:postgres:--x";
      };

  networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts =
    lib.optionals config.services.paperless.enable
      [ config.services.paperless.port ];

  virtualisation.vmVariant.services.paperless.enable = lib.mkForce false;
}
