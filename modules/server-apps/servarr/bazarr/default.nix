{ config, lib, ... }:

let
  inherit (config.dotfiles) server;
  inherit (server.storage) appData dataRoot;
in
{
  services.bazarr = {
    enable = true;
    dataDir = "${appData.root}/bazarr";
    settings.general.ip = "0.0.0.0";
  };

  users.users.${config.services.bazarr.user}.extraGroups = [
    appData.group.name
    dataRoot.group.name
  ];

  systemd.services.bazarr = {
    unitConfig.RequiresMountsFor = [ "${dataRoot.path}/media" ];
    serviceConfig.UMask = lib.mkForce "0002";
  };

  networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts = [
    config.services.bazarr.settings.general.port
  ];
}
