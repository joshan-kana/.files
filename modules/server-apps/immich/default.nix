{ config, lib, ... }:

let
  serverCfg = config.dotfiles.server;
  inherit (serverCfg) storage;
  mediaLocation = "${storage.dataRoot.path}/immich";
  backupLocation = "${mediaLocation}/backups";
in
{
  services.immich = {
    enable = true;
    host = serverCfg.lan.serverIp;
    openFirewall = false;
    inherit mediaLocation;
    group = storage.dataRoot.group.name;

    settings.backup.database.cronExpression = "*/${toString storage.snapshots.intervalMinutes} * * * *";
  };

  networking.firewall.interfaces.${serverCfg.lan.interface}.allowedTCPPorts =
    lib.optionals config.services.immich.enable
      [ config.services.immich.port ];

  services.restic.backups.apps.paths = [ backupLocation ];

  systemd = lib.mkIf config.services.immich.enable {
    tmpfiles.rules = [
      "d ${backupLocation} 2770 immich ${storage.dataRoot.group.name} - -"
    ];
  };

  virtualisation.vmVariant.services.immich.enable = lib.mkForce false;
}
