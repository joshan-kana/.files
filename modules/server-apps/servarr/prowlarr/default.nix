{ config, lib, ... }:

let
  inherit (config.dotfiles) server;
  inherit (server.storage) appData;
in
{
  services.prowlarr = {
    enable = true;
    dataDir = "${appData.root}/prowlarr";
    settings.server.bindaddress = "*";
  };

  systemd = {
    services.prowlarr = {
      serviceConfig.StateDirectoryMode = "0700";
    };
    # Prowlarr's DynamicUser owns this directory; tmpfiles must not reset it.
    tmpfiles.settings."10-prowlarr"."${appData.root}/prowlarr".d = {
      user = lib.mkForce "-";
      group = lib.mkForce "-";
      mode = lib.mkForce "-";
    };
  };

  networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts = [
    config.services.prowlarr.settings.server.port
  ];
}
