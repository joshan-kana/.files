{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.dotfiles) server;
  inherit (server.storage) appData;

  gatewayRoot = "${appData.root}/mcp-gateway";
  gatewayPort = 4444;
  gatewayUrl = "http://${server.lan.serverIp}:${toString gatewayPort}";
  apiUrl = "${gatewayUrl}/v1";
  gatewaySecret = "${server.secretsDir}/mcp-gateway.env";
  syncSecret = "${server.secretsDir}/mcp-gateway-sync.env";
  sharedServerIdFile = "/run/mcp-gateway/shared-agent-tools.id";

  agentMailEnabled = config.dotfiles.resolvedScopes.serverApps.agentTools.agentMail.enable;
  n8nEnabled = config.dotfiles.resolvedScopes.serverApps.n8n.enable;
  agentMailPort = config.virtualisation.oci-containers.containers.agent-mail.environment.HTTP_PORT;
  agentMailUrl = "http://${server.lan.serverIp}:${agentMailPort}/mcp/";
  n8nUrl = "http://${server.lan.serverIp}:5678/mcp-server/http";
  enabledGatewayUrls =
    lib.optionals agentMailEnabled [ agentMailUrl ] ++ lib.optionals n8nEnabled [ n8nUrl ];
  enabledGatewayUrlsJson = builtins.toJSON enabledGatewayUrls;

  catalog = (pkgs.formats.yaml { }).generate "mcp-catalog.yml" {
    catalog_servers =
      lib.optionals agentMailEnabled [
        {
          id = "agent-mail";
          name = "Agent Mail";
          category = "Agent Coordination";
          url = agentMailUrl;
          transport = "STREAMABLEHTTP";
          auth_type = "Open";
          provider = "Local";
          description = "Shared mailbox, agent coordination, and file reservations.";
          requires_api_key = false;
          tags = [
            "agents"
            "coordination"
            "files"
          ];
        }
      ]
      ++ lib.optionals n8nEnabled [
        {
          id = "n8n";
          name = "n8n";
          category = "Automation";
          url = n8nUrl;
          transport = "STREAMABLEHTTP";
          auth_type = "API Key";
          provider = "Local";
          description = "Shared workflow creation, maintenance, validation, and execution.";
          requires_api_key = true;
          secure = true;
          tags = [
            "automation"
            "workflows"
          ];
        }
      ];

    categories = [
      "Agent Coordination"
      "Automation"
    ];
    auth_types = [
      "Open"
      "API Key"
    ];
  };

  syncSharedServer = pkgs.writeShellApplication {
    name = "mcp-gateway-sync";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      jq
    ];
    text = ''
      set -euo pipefail
      : "''${MCPGATEWAY_BEARER_TOKEN:?MCPGATEWAY_BEARER_TOKEN is not set}"

      auth=(--header "Authorization: Bearer $MCPGATEWAY_BEARER_TOKEN")

      for _ in $(seq 1 60); do
        if curl --fail --silent "${gatewayUrl}/ready" >/dev/null; then
          break
        fi
        sleep 1
      done
      curl --fail --silent "${gatewayUrl}/ready" >/dev/null

      gateways="$(${pkgs.curl}/bin/curl --fail --silent "''${auth[@]}" \
        "${apiUrl}/gateways?limit=0&include_pagination=false")"

      registerCatalogServer() {
        local catalogId="$1"
        local upstreamUrl="$2"
        local body="$3"

        if jq -e --arg url "$upstreamUrl" '.[] | select(.url == $url)' <<<"$gateways" >/dev/null; then
          return
        fi

        response="$(${pkgs.curl}/bin/curl --fail --silent --request POST \
          "''${auth[@]}" --header 'Content-Type: application/json' \
          --data "$body" "${apiUrl}/catalog/$catalogId/register")"
        if [ "$(jq -r '.success' <<<"$response")" != true ]; then
          jq -r '.message // "Catalog registration failed"' <<<"$response" >&2
          exit 1
        fi

        gateways="$(${pkgs.curl}/bin/curl --fail --silent "''${auth[@]}" \
          "${apiUrl}/gateways?limit=0&include_pagination=false")"
      }

      ${lib.optionalString agentMailEnabled ''
        registerCatalogServer agent-mail '${agentMailUrl}' '{}'
      ''}
      ${lib.optionalString n8nEnabled ''
        : "''${N8N_MCP_API_KEY:?N8N_MCP_API_KEY is not set}"
        n8nBody="$(jq -cn --arg apiKey "$N8N_MCP_API_KEY" '{api_key: $apiKey}')"
        registerCatalogServer n8n '${n8nUrl}' "$n8nBody"
      ''}

      gatewayIds="$(jq -c --argjson urls '${enabledGatewayUrlsJson}' '[.[] | select(.url as $url | $urls | index($url)) | .id]' <<<"$gateways")"

      tools="$(${pkgs.curl}/bin/curl --fail --silent "''${auth[@]}" \
        "${apiUrl}/tools?limit=0&include_pagination=false")"
      toolIds="$(jq -c --argjson gatewayIds "$gatewayIds" '[.[] | select((.gateway_id // .gatewayId) as $id | $gatewayIds | index($id)) | .id]' <<<"$tools")"

      servers="$(${pkgs.curl}/bin/curl --fail --silent "''${auth[@]}" \
        "${apiUrl}/servers?include_pagination=false")"
      serverId="$(jq -r '.[] | select(.name == "shared-agent-tools") | .id' <<<"$servers" | head -n1)"

      serverBody="$(jq -cn --argjson tools "$toolIds" '{
        name: "shared-agent-tools",
        description: "Shared MCP tools for ChatGPT, Codex, Open WebUI, and other agents.",
        associated_tools: $tools
      }')"
      createBody="$(jq -cn --argjson server "$serverBody" '{ server: $server }')"

      if [ -z "$serverId" ]; then
        response="$(${pkgs.curl}/bin/curl --fail --silent --request POST \
          "''${auth[@]}" --header 'Content-Type: application/json' \
          --data "$createBody" "${apiUrl}/servers")"
        serverId="$(jq -r '.id' <<<"$response")"
      else
        ${pkgs.curl}/bin/curl --fail --silent --request PUT \
          "''${auth[@]}" --header 'Content-Type: application/json' \
          --data "$serverBody" "${apiUrl}/servers/$serverId" >/dev/null
      fi

      test -n "$serverId"
      tmp="$(mktemp /run/mcp-gateway/.shared-agent-tools.id.XXXXXX)"
      trap 'rm -f "$tmp"' EXIT
      printf '%s\n' "$serverId" >"$tmp"
      chmod 0644 "$tmp"
      mv "$tmp" ${sharedServerIdFile}
      trap - EXIT
    '';
  };
in
{
  virtualisation.oci-containers.containers.mcp-gateway = {
    image = "ghcr.io/ibm/mcp-context-forge:v1.0.9";
    environment = {
      HOST = server.lan.serverIp;
      PORT = toString gatewayPort;
      DATABASE_URL = "sqlite:////data/mcp.db";

      MCPGATEWAY_UI_ENABLED = "true";
      AUTO_REFRESH_SERVERS = "true";
      MCPGATEWAY_ADMIN_API_ENABLED = "true";
      MCPGATEWAY_CATALOG_ENABLED = "true";
      MCPGATEWAY_CATALOG_FILE = "/config/mcp-catalog.yml";
      MCPGATEWAY_CATALOG_AUTO_HEALTH_CHECK = "true";

      AUTH_REQUIRED = "true";
      MCP_CLIENT_AUTH_ENABLED = "true";
      MCP_REQUIRE_AUTH = "true";
      REQUIRE_STRONG_SECRETS = "true";
      LEGACY_API_ENABLED = "false";
      SECURE_COOKIES = "false";
      SSRF_ALLOWED_NETWORKS = builtins.toJSON [ "${server.lan.serverIp}/32" ];

      MCPGATEWAY_A2A_ENABLED = "false";
      LLMCHAT_ENABLED = "false";
    };
    environmentFiles = [ gatewaySecret ];
    volumes = [
      "${gatewayRoot}:/data"
      "${catalog}:/config/mcp-catalog.yml:ro"
    ];
    extraOptions = [ "--network=host" ];
  };

  systemd.tmpfiles.rules = [
    "d ${gatewayRoot} 0770 agent-tools ${appData.group.name} - -"
    "d /run/mcp-gateway 0755 root root - -"
  ];

  systemd.services = {
    docker-mcp-gateway.unitConfig.AssertPathExists = gatewaySecret;

    mcp-gateway-sync = {
      description = "Synchronize the shared ContextForge MCP virtual server";
      after = [ "docker-mcp-gateway.service" ];
      wants = [ "docker-mcp-gateway.service" ];
      unitConfig.AssertPathExists = syncSecret;
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = syncSecret;
        ExecStart = lib.getExe syncSharedServer;
      };
    };
  };

  systemd.timers.mcp-gateway-sync = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "30s";
      OnUnitActiveSec = "5m";
      Unit = "mcp-gateway-sync.service";
    };
  };

  networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts = [ gatewayPort ];
}
