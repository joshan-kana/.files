{ config, lib, ... }:

let
  storage = config.dotfiles.server.storage;
  mediaLocation = "${storage.dataRoot.path}/immich";
  backupLocation = "${mediaLocation}/backups";
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

  services.restic.backups.apps.paths = [ backupLocation ];

  systemd = lib.mkIf config.services.immich.enable {
    tmpfiles.rules = [
      "d ${backupLocation} 2770 immich ${storage.dataRoot.group.name} - -"
    ];
  };

  virtualisation.vmVariant.services.immich.enable = lib.mkForce false;
}
