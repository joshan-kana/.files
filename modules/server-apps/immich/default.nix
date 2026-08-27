{ config, lib, ... }:

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

    settings.backup.database.cronExpression = "*/${toString storage.snapshots.intervalMinutes} * * * *";
  };

  systemd = lib.mkIf config.services.immich.enable {
    tmpfiles.rules = [
      "d ${storage.appData.root}/immich 2770 immich ${storage.appData.group.name} - -"
      "d ${backupLocation} 2770 immich ${storage.appData.group.name} - -"
    ];

    services.immich-server.serviceConfig = {
      BindPaths = [ "${backupLocation}:${mediaLocation}/backups" ];
      SupplementaryGroups = lib.mkAfter [ storage.appData.group.name ];
    };
  };

  virtualisation.vmVariant.services.immich.enable = lib.mkForce false;
}
