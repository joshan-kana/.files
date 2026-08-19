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
  computerEnv = "${secretsDir}/open-webui-computer.env";
  macComputerEnv = "${secretsDir}/open-webui-mac-computer.env";
  computerHeaders = {
    X-OpenWebUI-Chat-Id = "{{CHAT_ID}}";
    X-OpenWebUI-Message-Id = "{{MESSAGE_ID}}";
    X-OpenWebUI-User-Message-Id = "{{USER_MESSAGE_ID}}";
    X-OpenWebUI-User-Message-Parent-Id = "{{USER_MESSAGE_PARENT_ID}}";
    X-OpenWebUI-Task = "{{TASK}}";
  };
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
      WEBUI_ADMIN_NAME = "Joshan";
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

  # Build the environment file at boot from durable root-only inputs. This keeps
  # Open WebUI's own encryption key stable and also seeds Computer connections
  # with the lineage headers recommended by Computer upstream. A Mac Computer
  # connection is added automatically when open-webui-mac-computer.env exists.
  systemd.services.open-webui-secrets = {
    description = "Provision persistent Open WebUI secrets and connections";
    before = [ "open-webui.service" ];
    after = [ "open-webui-computer-bootstrap.service" ];
    requires = [ "open-webui-computer-bootstrap.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      UMask = "0077";
    };
    path = with pkgs; [
      coreutils
      gnugrep
      gnused
      jq
      openssl
    ];
    script = ''
      set -euo pipefail

      install -d -m 0700 ${secretsDir}
      touch ${openWebuiEnv}
      chmod 0600 ${openWebuiEnv}

      get_value() {
        file="$1"
        key="$2"
        sed -n "s/^$key=//p" "$file" 2>/dev/null | tail -n 1
      }

      set_value() {
        key="$1"
        value="$2"
        tmp="$(mktemp)"
        grep -v "^$key=" ${openWebuiEnv} > "$tmp" || true
        printf '%s=%s\n' "$key" "$value" >> "$tmp"
        install -m 0600 "$tmp" ${openWebuiEnv}
        rm -f "$tmp"
      }

      ensure_value() {
        key="$1"
        value="$2"
        if [ -z "$(get_value ${openWebuiEnv} "$key")" ]; then
          set_value "$key" "$value"
        fi
      }

      ensure_value WEBUI_SECRET_KEY "$(openssl rand -hex 32)"
      ensure_value WEBUI_ADMIN_EMAIL "joshan@localhost"
      ensure_value WEBUI_ADMIN_PASSWORD "$(openssl rand -hex 32)"

      serverKey="$(get_value ${computerEnv} CPTR_GATEWAY_API_KEY)"
      if [ -z "$serverKey" ]; then
        echo "Server Computer gateway key is missing from ${computerEnv}" >&2
        exit 1
      fi

      baseUrls="http://${serverIp}:8000/v1"
      apiKeys="$serverKey"
      apiConfigs="$(jq -cn \
        --argjson headers '${builtins.toJSON computerHeaders}' \
        '{"0": {"enable": true, "prefix_id": "server", "provider": "Open WebUI Computer (server)", "headers": $headers}}'
      )"

      if [ -s ${macComputerEnv} ]; then
        macUrl="$(get_value ${macComputerEnv} CPTR_BASE_URL)"
        macKey="$(get_value ${macComputerEnv} CPTR_GATEWAY_API_KEY)"
        if [ -n "$macUrl" ] && [ -n "$macKey" ]; then
          baseUrls="$baseUrls;$macUrl"
          apiKeys="$apiKeys;$macKey"
          apiConfigs="$(jq -cn \
            --argjson current "$apiConfigs" \
            --argjson headers '${builtins.toJSON computerHeaders}' \
            '$current + {"1": {"enable": true, "prefix_id": "mac", "provider": "Open WebUI Computer (Mac)", "headers": $headers}}'
          )"
        fi
      fi

      set_value ENABLE_OPENAI_API True
      set_value OPENAI_API_BASE_URLS "$baseUrls"
      set_value OPENAI_API_KEYS "$apiKeys"
      set_value OPENAI_API_CONFIGS "$apiConfigs"

      githubToken="$(get_value ${openWebuiEnv} GITHUB_MCP_TOKEN)"
      if [ -n "$githubToken" ]; then
        toolServers="$(jq -cn \
          --arg key "$githubToken" \
          '[{"url":"http://${serverIp}:8082/mcp","path":"","type":"mcp","auth_type":"bearer","headers":null,"key":$key,"config":{"enable":true},"info":{"id":"github","name":"GitHub"}}]'
        )"
      else
        toolServers='[]'
      fi
      set_value TOOL_SERVER_CONNECTIONS "$toolServers"

      chmod 0400 ${openWebuiEnv}
    '';
  };

  systemd.tmpfiles.rules = [
    "d ${openWebuiStateDir} 0750 root ${appDataGroup} - -"
    "d ${secretsDir} 0700 root root - -"
    "Z ${secretsDir} ~0700 root root - -"
  ];
}
