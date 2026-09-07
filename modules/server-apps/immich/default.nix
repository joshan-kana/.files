{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:

let
  inherit (config.dotfiles) server;
  inherit (server) storage;
  inherit (storage) dataRoot;
  mediaLocation = "${dataRoot.path}/immich";
  backupLocation = "${mediaLocation}/backups";
in
{
  services.immich = {
    enable = true;
    package = inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system}.immich;
    host = server.lan.serverIp;
    openFirewall = false;
    inherit mediaLocation;
    group = dataRoot.group.name;

    settings.backup.database.cronExpression = "*/${toString storage.snapshots.intervalMinutes} * * * *";
  };

  networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts =
    lib.optionals config.services.immich.enable
      [ config.services.immich.port ];

  services.restic.backups.apps.paths = [ backupLocation ];

  systemd = lib.mkIf config.services.immich.enable {
    services.immich-server.serviceConfig.UMask = lib.mkForce "0007";

    tmpfiles = {
      settings.immich."${mediaLocation}".e.mode = lib.mkForce "2770";

      rules = [
        "d ${backupLocation} 2770 immich ${dataRoot.group.name} - -"
      ];
    };
  };

  virtualisation.vmVariant.services.immich.enable = lib.mkForce false;
}
