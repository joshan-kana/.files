{ config, ... }:

let
  serverCfg = config.dotfiles.server;
  appDataRoot = serverCfg.storage.appData.root;
  hostPort = 5678;
  n8nSecretFile = "${serverCfg.secretsDir}/n8n.env";
in
{
  virtualisation.oci-containers.containers.n8n = {
    image = "docker.n8n.io/n8nio/n8n:latest";

    volumes = [ "${appDataRoot}/n8n:/home/node/.n8n" ];
    ports = [ "${serverCfg.lan.serverIp}:${toString hostPort}:5678" ];

    environment = {
      GENERIC_TIMEZONE = config.time.timeZone;
    };
    environmentFiles = [ n8nSecretFile ];
  };

  systemd.services.docker-n8n.unitConfig.AssertPathExists = n8nSecretFile;
}
