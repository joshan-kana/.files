{ config, lib, ... }:

let
  inherit (config.dotfiles) server;
  inherit (server) storage;
  mediaLocation = "${storage.dataRoot.path}/immich";
  backupLocation = "${mediaLocation}/backups";
in
{
  services.immich = {
    enable = true;
    host = server.lan.serverIp;
    openFirewall = false;
    inherit mediaLocation;
    group = storage.dataRoot.group.name;

    settings.backup.database.cronExpression = "*/${toString storage.snapshots.intervalMinutes} * * * *";
  };

  networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts =
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
