{ config, lib, ... }:

let
  serverCfg = config.dotfiles.server;
  inherit (serverCfg) secretsDir;
  appDataRoot = serverCfg.storage.appData.root;
  serverIp = serverCfg.lan.serverIp;
in
{
  virtualisation.oci-containers.containers.openproject = {
    image = "openproject/openproject:17";

    volumes = [
      "${appDataRoot}/openproject/pgdata:/var/openproject/pgdata"
      "${appDataRoot}/openproject/assets:/var/openproject/assets"
    ];

    ports = [ "${serverIp}:8081:80" ];

    environment = {
      OPENPROJECT_HOST__NAME = "${serverIp}:8081";
      OPENPROJECT_HTTPS = "false";
      OPENPROJECT_DEFAULT__LANGUAGE = "en";
    };
    environmentFiles = [ "${secretsDir}/openproject.env" ];
  };

  virtualisation.vmVariant.virtualisation.oci-containers.containers.openproject.ports =
    lib.mkForce [ "8081:80" ];
}
