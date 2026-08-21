{ config, ... }:

let
  storage = config.dotfiles.server.storage;
  backupLocation = "${storage.appData.root}/immich/backups";
  mediaLocation = "${storage.dataRoot.path}/immich";
in
{
  services.immich = {
    enable = true;
    host = config.dotfiles.server.lan.serverIp;
    openFirewall = true;
    inherit mediaLocation;
    group = storage.dataRoot.group.name;

    settings.backup.database.cronExpression =
      "*/${toString storage.snapshots.intervalMinutes} * * * *";
  };

  systemd.tmpfiles.rules = [
    "d ${storage.appData.root}/immich 2770 immich ${storage.appData.group.name} - -"
    "d ${backupLocation} 2770 immich ${storage.appData.group.name} - -"
  ];

  systemd.services.immich-server.serviceConfig = {
    BindPaths = [ "${backupLocation}:${mediaLocation}/backups" ];
    SupplementaryGroups = [ storage.appData.group.name ];
  };
}
