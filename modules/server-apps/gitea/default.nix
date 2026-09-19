{ config, lib, ... }:

let
  inherit (config.dotfiles) server;
in
{
  users.users = lib.mkIf config.services.gitea.enable {
    gitea.uid = 995;
  };

  services.gitea = {
    enable = true;
    stateDir = "${server.storage.appData.root}/gitea";
    group = server.storage.appData.group.name;
    database.type = "sqlite3";

    settings = {
      actions.ENABLED = true;

      server = {
        DOMAIN = server.lan.serverIp;
        HTTP_ADDR = server.lan.serverIp;
        HTTP_PORT = 3000;
        SSH_DOMAIN = server.lan.serverIp;
      };
    };
  };

  networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts =
    lib.optionals config.services.gitea.enable
      [ config.services.gitea.settings.server.HTTP_PORT ];

  virtualisation.vmVariant.services.gitea.enable = lib.mkForce false;
}
