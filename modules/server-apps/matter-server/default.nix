{ config, ... }:

let
  serverCfg = config.dotfiles.server;
  appDataRoot = serverCfg.storage.appData.root;
in
{
  networking.firewall.interfaces.${serverCfg.lan.interface}.allowedTCPPorts = [ 5580 ];

  virtualisation.oci-containers.containers.matter-server = {
    image = "ghcr.io/home-assistant-libs/python-matter-server:stable";

    volumes = [ "${appDataRoot}/matter-server:/data" ];

    extraOptions = [
      "--network=host"
      "--cap-add=NET_ADMIN"
      "--cap-add=NET_RAW"
    ];
  };
}
