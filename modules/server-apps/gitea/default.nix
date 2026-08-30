{ config, lib, ... }:

let
  inherit (config.dotfiles) server;
  serverIp = server.lan.serverIp;
in
{
  services.gitea = {
    enable = true;
    stateDir = "${server.storage.appData.root}/gitea";
    group = server.storage.appData.group.name;
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

  networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts =
    lib.optionals config.services.gitea.enable
      [ config.services.gitea.settings.server.HTTP_PORT ];

  virtualisation.vmVariant.services.gitea.enable = lib.mkForce false;
}
