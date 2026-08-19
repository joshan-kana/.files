{
  config,
  lib,
  ...
}:

let
  serverCfg = config.dotfiles.server;
  inherit (serverCfg) secretsDir;
  appDataRoot = serverCfg.storage.appData.root;
  appDataGroup = serverCfg.storage.appData.group.name;
  openWebuiStateDir = "${appDataRoot}/open-webui";
  openWebuiPort = 8080;
in
{
  services.open-webui = {
    enable = true;
    stateDir = openWebuiStateDir;
    host = serverCfg.lan.serverIp;
    port = openWebuiPort;
    environmentFile = "${secretsDir}/open-webui.env";
    environment = {
      WEBUI_URL = "http://${serverCfg.lan.serverIp}:${toString openWebuiPort}";
      ENABLE_SIGNUP = "False";
    };
    openFirewall = true;
  };

  # The upstream module normally owns /var/lib/open-webui. Keep all application
  # state under the server's canonical app-data tree so Snapper and Restic cover
  # it together with the other services.
  systemd.services.open-webui.serviceConfig = {
    StateDirectory = lib.mkForce "apps/open-webui";
    SupplementaryGroups = lib.mkAfter [ appDataGroup ];
  };

  systemd.tmpfiles.rules = [
    "d ${openWebuiStateDir} 0750 root ${appDataGroup} - -"
    "d ${secretsDir} 0700 root root - -"
    "Z ${secretsDir} ~0700 root root - -"
    "z ${secretsDir}/open-webui.env 0400 root root - -"
  ];
}
