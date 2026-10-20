{ config, lib, ... }:

let
  inherit (config.dotfiles) server;
  inherit (server.storage) appData dataRoot;
in
{
  services.sonarr = {
    enable = true;
    dataDir = "${appData.root}/sonarr";
    settings.server.bindaddress = "*";
  };

  users.users.${config.services.sonarr.user}.extraGroups = [
    appData.group.name
    dataRoot.group.name
  ];

  systemd = {
    services.sonarr = {
      unitConfig.RequiresMountsFor = [ "${dataRoot.path}/media" ];
      serviceConfig.UMask = lib.mkForce "0002";
    };
    tmpfiles.rules = [
      "d ${appData.root}/sonarr 0700 ${config.services.sonarr.user} ${config.services.sonarr.group} - -"
    ];
  };

  networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts = [
    config.services.sonarr.settings.server.port
  ];
}
