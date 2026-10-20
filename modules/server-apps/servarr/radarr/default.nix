{ config, lib, ... }:

let
  inherit (config.dotfiles) server;
  inherit (server.storage) appData dataRoot;
in
{
  services.radarr = {
    enable = true;
    dataDir = "${appData.root}/radarr";
    settings.server.bindaddress = "*";
  };

  users.users.${config.services.radarr.user}.extraGroups = [
    appData.group.name
    dataRoot.group.name
  ];

  systemd.services.radarr = {
    unitConfig.RequiresMountsFor = [ "${dataRoot.path}/media" ];
    serviceConfig.UMask = lib.mkForce "0002";
  };

  networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts = [
    config.services.radarr.settings.server.port
  ];
}
