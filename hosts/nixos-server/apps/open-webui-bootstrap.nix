{
  config,
  pkgs,
  ...
}:

let
  serverCfg = config.dotfiles.server;
  inherit (serverCfg) secretsDir;
  serverIp = serverCfg.lan.serverIp;
  openWebuiPort = 8080;
  openWebuiEnv = "${secretsDir}/open-webui.env";
  githubEnv = "${secretsDir}/openclaw-github.env";
  baseUrl = "http://${serverIp}:${toString openWebuiPort}";
  recoveryFilter = ../open-webui/functions/restart_recovery_filter.py;
  recoveryEvent = ../open-webui/functions/restart_recovery_event.py;
in
{
  services.open-webui.environment.ENABLE_PLUGINS = "True";

  systemd.services.open-webui-bootstrap = {
    description = "Reconcile Open WebUI agent workspace integrations";
    wantedBy = [ "multi-user.target" ];
    after = [ "open-webui.service" ];
    requires = [ "open-webui.service" ];
    unitConfig.AssertPathIsRegular = [
      openWebuiEnv
      githubEnv
    ];
    path = with pkgs; [
      coreutils
      curl
      gnugrep
      gnused
      jq
    ];
    serviceConfig = {
      Type = "oneshot";
      UMask = "0077";
    };
    script = ''
      set -euo pipefail

      get_value() {
        file="$1"
        key="$2"
        sed -n "s/^$key=//p" "$file" | tail -n 1
      }

      for _ in $(seq 1 90); do
        if curl -fsS ${baseUrl}/api/config >/dev/null 2>&1; then
          break
        fi
        sleep 1
      done
      curl -fsS ${baseUrl}/api/config >/dev/null

      adminEmail="$(get_value ${openWebuiEnv} WEBUI_ADMIN_EMAIL)"
      adminPassword="$(get_value ${openWebuiEnv} WEBUI_ADMIN_PASSWORD)"
      : "''${adminEmail:?${openWebuiEnv} must define WEBUI_ADMIN_EMAIL}"
      : "''${adminPassword:?${openWebuiEnv} must define WEBUI_ADMIN_PASSWORD}"

      token="$(
        curl -fsS \
          -H 'Content-Type: application/json' \
          -d "$(jq -cn --arg e "$adminEmail" --arg p "$adminPassword" '{email:$e,password:$p}')" \
          ${baseUrl}/api/v1/auths/signin | jq -r '.token'
      )"
      test -n "$token"
      test "$token" != null
      auth=(-H "Authorization: Bearer $token")

      # Persistent environment variables seed first boot. Reconcile the same
      # connection set through the supported admin API so later secret/config
      # changes also take effect after Open WebUI has persisted its Config DB.
      apiBaseUrls="$(get_value ${openWebuiEnv} OPENAI_API_BASE_URLS)"
      apiKeys="$(get_value ${openWebuiEnv} OPENAI_API_KEYS)"
      apiConfigs="$(get_value ${openWebuiEnv} OPENAI_API_CONFIGS)"
      urlsJson="$(printf '%s' "$apiBaseUrls" | jq -R 'split(";") | map(select(length > 0))')"
      keysJson="$(printf '%s' "$apiKeys" | jq -R 'split(";")')"

      curl -fsS \
        "''${auth[@]}" \
        -H 'Content-Type: application/json' \
        -d "$(jq -cn \
          --argjson urls "$urlsJson" \
          --argjson keys "$keysJson" \
          --argjson configs "$apiConfigs" \
          '{ENABLE_OPENAI_API:true,OPENAI_API_BASE_URLS:$urls,OPENAI_API_KEYS:$keys,OPENAI_API_CONFIGS:$configs}'
        )" \
        ${baseUrl}/openai/config/update >/dev/null

      githubToken="$(get_value ${githubEnv} GH_TOKEN)"
      : "''${githubToken:?${githubEnv} must define GH_TOKEN}"
      toolServers="$(jq -cn \
        --arg key "$githubToken" \
        '[{"url":"http://${serverIp}:8082/mcp","path":"","type":"mcp","auth_type":"bearer","headers":null,"key":$key,"config":{"enable":true},"info":{"id":"github","name":"GitHub"}}]'
      )"
      curl -fsS \
        "''${auth[@]}" \
        -H 'Content-Type: application/json' \
        -d "$(jq -cn --argjson connections "$toolServers" '{TOOL_SERVER_CONNECTIONS:$connections}')" \
        ${baseUrl}/api/v1/configs/tool_servers >/dev/null

      reconcile_function() {
        id="$1"
        name="$2"
        source="$3"
        makeGlobal="$4"

        content="$(cat "$source")"
        payload="$(jq -cn \
          --arg id "$id" \
          --arg name "$name" \
          --arg content "$content" \
          '{id:$id,name:$name,content:$content,meta:{description:"Managed by joshan-kana/.files"}}'
        )"

        if current="$(curl -fsS "''${auth[@]}" ${baseUrl}/api/v1/functions/id/$id 2>/dev/null)"; then
          curl -fsS \
            "''${auth[@]}" \
            -H 'Content-Type: application/json' \
            -d "$payload" \
            ${baseUrl}/api/v1/functions/id/$id/update >/dev/null
        else
          curl -fsS \
            "''${auth[@]}" \
            -H 'Content-Type: application/json' \
            -d "$payload" \
            ${baseUrl}/api/v1/functions/create >/dev/null
        fi

        current="$(curl -fsS "''${auth[@]}" ${baseUrl}/api/v1/functions/id/$id)"
        if [ "$(printf '%s' "$current" | jq -r '.is_active')" != true ]; then
          curl -fsS -X POST "''${auth[@]}" ${baseUrl}/api/v1/functions/id/$id/toggle >/dev/null
          current="$(curl -fsS "''${auth[@]}" ${baseUrl}/api/v1/functions/id/$id)"
        fi

        if [ "$makeGlobal" = true ] && [ "$(printf '%s' "$current" | jq -r '.is_global')" != true ]; then
          curl -fsS -X POST "''${auth[@]}" ${baseUrl}/api/v1/functions/id/$id/toggle/global >/dev/null
        fi
      }

      reconcile_function restart_recovery_filter "Restart Recovery Marker" ${recoveryFilter} true
      reconcile_function restart_recovery_event "Restart Recovery" ${recoveryEvent} false
    '';
  };
}
