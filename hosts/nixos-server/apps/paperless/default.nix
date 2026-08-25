{ config, lib, ... }:

let
  server = config.dotfiles.server;
  dataDir = "${server.storage.appData.root}/paperless";
in
{
  services.paperless = {
    enable = true;
    address = server.lan.serverIp;
    inherit dataDir;
    mediaDir = "${server.storage.dataRoot.path}/paperless/media";
    consumptionDir = "${server.storage.dataRoot.path}/paperless/consume";
    database.createLocally = true;
  };

  services.postgresqlBackup = lib.mkIf config.services.paperless.enable {
    enable = true;
    databases = [ "paperless" ];
    location = "${dataDir}/backups";
    startAt = "*:0/${toString server.storage.snapshots.intervalMinutes}";
  };

  networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts =
    lib.optionals config.services.paperless.enable
      [ config.services.paperless.port ];
}
