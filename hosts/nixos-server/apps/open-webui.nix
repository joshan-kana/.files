{
  config,
  lib,
  pkgs,
  ...
}:

let
  serverCfg = config.dotfiles.server;
  inherit (serverCfg) secretsDir;
  appDataRoot = serverCfg.storage.appData.root;
  appDataGroup = serverCfg.storage.appData.group.name;
  serverIp = serverCfg.lan.serverIp;
  openWebuiStateDir = "${appDataRoot}/open-webui";
  openWebuiPort = 8080;
  openWebuiEnv = "${secretsDir}/open-webui.env";
in
{
  services.open-webui = {
    enable = true;
    stateDir = openWebuiStateDir;
    host = serverIp;
    port = openWebuiPort;
    environmentFile = openWebuiEnv;
    environment = {
      WEBUI_URL = "http://${serverIp}:${toString openWebuiPort}";
      ENABLE_WEB_SEARCH = "True";
      WEB_SEARCH_ENGINE = "searxng";
      WEB_SEARCH_RESULT_COUNT = "5";
      WEB_SEARCH_CONCURRENT_REQUESTS = "5";
      SEARXNG_QUERY_URL = "http://${serverIp}:8888/search?q=<query>";
    };
    openFirewall = true;
  };

  # The upstream module normally owns /var/lib/open-webui. Keep all application
  # state under the server's canonical app-data tree so Snapper and Restic cover
  # it together with the other services.
  systemd.services.open-webui = {
    after = [ "open-webui-secrets.service" ];
    requires = [ "open-webui-secrets.service" ];
    serviceConfig = {
      StateDirectory = lib.mkForce "apps/open-webui";
      SupplementaryGroups = lib.mkAfter [ appDataGroup ];
    };
  };

  systemd.services.open-webui-secrets = {
    description = "Provision persistent Open WebUI secrets";
    before = [ "open-webui.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      UMask = "0077";
    };
    path = with pkgs; [
      coreutils
      gnugrep
      openssl
    ];
    script = ''
      set -euo pipefail

      install -d -m 0700 ${secretsDir}
      touch ${openWebuiEnv}
      chmod 0400 ${openWebuiEnv}

      append_if_missing() {
        key="$1"
        value="$2"
        if ! grep -q "^$key=" ${openWebuiEnv}; then
          chmod 0600 ${openWebuiEnv}
          printf '%s=%s\n' "$key" "$value" >> ${openWebuiEnv}
          chmod 0400 ${openWebuiEnv}
        fi
      }

      append_if_missing WEBUI_SECRET_KEY "$(openssl rand -hex 32)"
      append_if_missing WEBUI_ADMIN_EMAIL "joshan@localhost"
      append_if_missing WEBUI_ADMIN_PASSWORD "$(openssl rand -hex 32)"
    '';
  };

  systemd.tmpfiles.rules = [
    "d ${openWebuiStateDir} 0750 root ${appDataGroup} - -"
    "d ${secretsDir} 0700 root root - -"
    "Z ${secretsDir} ~0700 root root - -"
  ];
}
