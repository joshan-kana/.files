{ config, ... }:

let
  serverCfg = config.dotfiles.server;
  serverIp = serverCfg.lan.serverIp;
in
{
  services.gitea = {
    enable = true;
    stateDir = "${serverCfg.storage.appData.root}/gitea";
    database.type = "sqlite3";

    settings = {
      actions.ENABLED = true;

      server = {
        DOMAIN = serverIp;
        HTTP_ADDR = serverIp;
        HTTP_PORT = 3000;
        SSH_DOMAIN = serverIp;
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 3000 ];
}
