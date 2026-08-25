{ config, ... }:

let
  serverCfg = config.dotfiles.server;
  inherit (serverCfg) secretsDir;
  appDataRoot = serverCfg.storage.appData.root;
in
{
  networking.firewall.allowedTCPPorts = [ 5678 ];

  virtualisation.oci-containers.containers.n8n = {
    image = "docker.n8n.io/n8nio/n8n:latest";

    volumes = [ "${appDataRoot}/n8n:/home/node/.n8n" ];
    ports = [ "5678:5678" ];

    environment = {
      GENERIC_TIMEZONE = config.time.timeZone;
    };
    environmentFiles = [ "${secretsDir}/n8n.env" ];
  };
}
