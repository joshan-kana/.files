{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.dotfiles) server;

  serviceUser = "chatgpt-shared-tools";
  tunnelSecret = "${server.secretsDir}/chatgpt-shared-tools.env";
  gatewayPort = config.virtualisation.oci-containers.containers.mcp-gateway.environment.PORT;
  gatewayUrl = "http://${server.lan.serverIp}:${gatewayPort}";
  tunnelClient = import ../openai-tunnel-client.nix { inherit pkgs; };
  mcpGatewayEnabled = config.dotfiles.resolvedScopes.serverApps.agentTools.mcpGateway.enable;

  start = pkgs.writeShellScript "chatgpt-shared-tools-start" ''
    set -euo pipefail
    : "''${MCPGATEWAY_BEARER_TOKEN:?MCPGATEWAY_BEARER_TOKEN is not set}"
    : "''${MCPGATEWAY_SERVER_ID:?MCPGATEWAY_SERVER_ID is not set}"

    for _ in {1..300}; do
      if ${pkgs.curl}/bin/curl --fail --silent "${gatewayUrl}/ready" >/dev/null; then
        break
      fi
      ${pkgs.coreutils}/bin/sleep 1
    done
    ${pkgs.curl}/bin/curl --fail --silent "${gatewayUrl}/ready" >/dev/null

    export MCP_SERVER_URL="url=${gatewayUrl}/servers/$MCPGATEWAY_SERVER_ID/mcp"
    export MCPGATEWAY_AUTH="Bearer $MCPGATEWAY_BEARER_TOKEN"
    export MCP_EXTRA_HEADERS="Authorization: env:MCPGATEWAY_AUTH"
    export MCP_DISCOVERY_EXTRA_HEADERS="Authorization: env:MCPGATEWAY_AUTH"

    exec ${tunnelClient}/bin/tunnel-client run \
      --log.level=info \
      --log.format=struct-text
  '';
in
{
  users.groups.${serviceUser} = lib.mkIf mcpGatewayEnabled { };
  users.users.${serviceUser} = lib.mkIf mcpGatewayEnabled {
    isSystemUser = true;
    group = serviceUser;
  };

  systemd.services.chatgpt-shared-tools = lib.mkIf mcpGatewayEnabled {
    description = "Shared agent MCP tools through OpenAI Secure MCP Tunnel";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "docker-mcp-gateway.service"
    ];
    requires = [ "docker-mcp-gateway.service" ];
    wants = [ "network-online.target" ];

    unitConfig.AssertPathExists = tunnelSecret;

    environment.HEALTH_LISTEN_ADDR = "127.0.0.1:18793";

    serviceConfig = {
      Type = "simple";
      User = serviceUser;
      EnvironmentFile = tunnelSecret;
      ExecStart = start;
      Restart = "always";
      RestartSec = "2s";
      UMask = "0077";
    };
  };
}
