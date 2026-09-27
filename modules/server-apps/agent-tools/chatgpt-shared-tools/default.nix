{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.dotfiles) server;
  gatewayEnabled = config.dotfiles.resolvedScopes.serverApps.agentTools.mcpGateway.enable;

  tunnelSecret = "${server.secretsDir}/chatgpt-shared-tools.env";
  tunnelClient = import ../openai-tunnel-client.nix { inherit inputs pkgs; };

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
      };

      serviceConfig = {
        DynamicUser = true;
        EnvironmentFile = tunnelSecret;
        ExecStart = "${tunnelClient}/bin/tunnel-client run --log.level=info --log.format=struct-text";
        Restart = "always";
        RestartSec = "2s";
        UMask = "0077";
      };
    };
  };
}
