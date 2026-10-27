{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.dotfiles) server;
  gatewayEnabled = config.dotfiles.resolvedScopes.serverApps.agentTools.mcpGateway.enable;

  tunnelSecret = "${server.secretsDir}/chatgpt-shared-tools.env";
  start = pkgs.writeShellScript "chatgpt-shared-tools-start" ''
    set -euo pipefail
    : "''${MCPGATEWAY_BEARER_TOKEN:?MCPGATEWAY_BEARER_TOKEN is not set}"
    export MCPGATEWAY_AUTH="Bearer $MCPGATEWAY_BEARER_TOKEN"
    export MCP_EXTRA_HEADERS="Authorization: env:MCPGATEWAY_AUTH"
    export MCP_DISCOVERY_EXTRA_HEADERS="Authorization: env:MCPGATEWAY_AUTH"
    exec ${pkgs.openai-tunnel-client}/bin/tunnel-client run --log.level=info --log.format=struct-text
  '';

in
{
  config = lib.mkIf gatewayEnabled {
    systemd.services.chatgpt-shared-tools = {
      description = "Shared agent MCP tools through OpenAI Secure MCP Tunnel";
      wantedBy = [ "multi-user.target" ];
      after = [ "agentgateway.service" ];
      requires = [ "agentgateway.service" ];

      unitConfig.AssertPathExists = tunnelSecret;

      environment = {
        HEALTH_LISTEN_ADDR = "127.0.0.1:18793";
        MCP_SERVER_URL = "url=http://127.0.0.1:4444/mcp";
        MCP_STARTUP_WAIT_TIMEOUT = "30s";
        CONTROL_PLANE_POLL_CHANNELS = "main";
      };

      serviceConfig = {
        DynamicUser = true;
        EnvironmentFile = tunnelSecret;
        ExecStart = start;
        Restart = "always";
        RestartSec = "2s";
        UMask = "0077";
      };
    };
  };
}
