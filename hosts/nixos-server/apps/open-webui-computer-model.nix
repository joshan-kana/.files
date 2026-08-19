{
  config,
  lib,
  pkgs,
  ...
}:

let
  primaryUser = config.dotfiles.users.primary.name;
  serverCfg = config.dotfiles.server;
  inherit (serverCfg) secretsDir;
  appDataRoot = serverCfg.storage.appData.root;
  computerPort = 8000;
  computerRoot = "${appDataRoot}/open-webui-computer";
  computerEnv = "${secretsDir}/open-webui-computer.env";
  openRouterEnv = "${secretsDir}/server-zdr-openrouter.env";
  computerBaseUrl = "http://${serverCfg.lan.serverIp}:${toString computerPort}";
  defaultModel = "openrouter-zdr/minimax/minimax-m3";
in
{
  # The base bootstrap uses sed to maintain its root-only environment file.
  systemd.services.open-webui-computer-bootstrap.path = lib.mkAfter [ pkgs.gnused ];

  # Open WebUI should not consume the Computer gateway until its default model
  # backend has also been reconciled.
  systemd.services.open-webui-secrets = {
    after = lib.mkAfter [ "open-webui-computer-model.service" ];
    requires = lib.mkAfter [ "open-webui-computer-model.service" ];
  };

  systemd.services.open-webui-computer-model = {
    description = "Configure the server Computer AI backend";
    wantedBy = [ "multi-user.target" ];
    after = [ "open-webui-computer-bootstrap.service" ];
    requires = [ "open-webui-computer-bootstrap.service" ];
    unitConfig.AssertPathIsRegular = [ openRouterEnv ];
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

      adminPassword="$(get_value ${computerEnv} CPTR_ADMIN_PASSWORD)"
      openRouterKey="$(get_value ${openRouterEnv} OPENROUTER_ZDR_API_KEY)"
      : "''${adminPassword:?${computerEnv} must define CPTR_ADMIN_PASSWORD}"
      : "''${openRouterKey:?${openRouterEnv} must define OPENROUTER_ZDR_API_KEY}"

      cookies="$(mktemp)"
      trap 'rm -f "$cookies"' EXIT

      curl -fsS \
        -c "$cookies" \
        -H 'Content-Type: application/json' \
        -d "$(jq -cn --arg u '${primaryUser}' --arg p "$adminPassword" '{username:$u,password:$p}')" \
        ${computerBaseUrl}/api/auth/login >/dev/null

      existing="$(curl -fsS -b "$cookies" ${computerBaseUrl}/api/admin/connections)"
      connectionId="$(printf '%s' "$existing" | jq -r '.connections[]? | select(.name == "OpenRouter ZDR") | .id' | head -n 1)"

      payload="$(jq -cn \
        --arg key "$openRouterKey" \
        '{name:"OpenRouter ZDR",provider:"openai",api_type:"chat_completions",prefix_id:"openrouter-zdr",base_url:"https://openrouter.ai/api/v1",api_key:$key,enabled:true,models:["minimax/minimax-m3","z-ai/glm-5.2"]}'
      )"

      if [ -n "$connectionId" ]; then
        curl -fsS \
          -b "$cookies" \
          -X PUT \
          -H 'Content-Type: application/json' \
          -d "$payload" \
          "${computerBaseUrl}/api/admin/connections/$connectionId" >/dev/null
      else
        curl -fsS \
          -b "$cookies" \
          -H 'Content-Type: application/json' \
          -d "$payload" \
          ${computerBaseUrl}/api/admin/connections >/dev/null
      fi

      curl -fsS \
        -b "$cookies" \
        -X PUT \
        -H 'Content-Type: application/json' \
        -d '${builtins.toJSON { config = { "chat.default_model" = defaultModel; }; }}' \
        ${computerBaseUrl}/api/admin/config >/dev/null

      # The one-time setup URL is no longer useful after the first account has
      # been created; do not retain it in the persistent startup log.
      truncate -s 0 ${computerRoot}/startup.log
    '';
  };
}
