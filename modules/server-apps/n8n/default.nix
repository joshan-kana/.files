{ config, ... }:

let
  inherit (config.dotfiles) server;
  hostPort = 5678;
  n8nSecret = "${server.secretsDir}/n8n.env";
in
{
  dotfiles.secrets.requiredFiles = [ n8nSecret ];

  virtualisation.oci-containers.containers.n8n = {
    image = "docker.io/n8nio/n8n:latest";

    volumes = [ "${server.storage.appData.root}/n8n:/home/node/.n8n" ];
    ports = [ "${server.lan.serverIp}:${toString hostPort}:5678" ];

    environment = {
      GENERIC_TIMEZONE = config.time.timeZone;
    };
    environmentFiles = [ n8nSecret ];
  };

  systemd.services.docker-n8n.unitConfig.AssertPathExists = n8nSecret;
}
