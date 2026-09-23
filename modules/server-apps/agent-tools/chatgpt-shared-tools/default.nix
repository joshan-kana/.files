{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.dotfiles) server;
  inherit (config.dotfiles.resolvedScopes.serverApps.agentTools.mcpGateway) enable;

  serviceUser = "chatgpt-shared-tools";
  tunnelSecret = "${server.secretsDir}/chatgpt-shared-tools.env";
  gatewayUrl = "http://127.0.0.1:4444";
  tunnelClient = import ../openai-tunnel-client.nix { inherit inputs pkgs; };

  start = pkgs.writeShellScript "chatgpt-shared-tools-start" ''
    set -euo pipefail
    for _ in {1..60}; do
      if ${pkgs.curl}/bin/curl --fail --silent "http://127.0.0.1:15021/healthz/ready" >/dev/null; then
        break
      fi
      ${pkgs.coreutils}/bin/sleep 1
    done
    ${pkgs.curl}/bin/curl --fail --silent "http://127.0.0.1:15021/healthz/ready" >/dev/null

    export MCP_SERVER_URL="url=${gatewayUrl}/mcp"

    exec ${tunnelClient}/bin/tunnel-client run \
      --log.level=info \
      --log.format=struct-text
  '';
in
{
  users.groups.${serviceUser} = lib.mkIf enable { };
  users.users.${serviceUser} = lib.mkIf enable {
    isSystemUser = true;
    group = serviceUser;
  };

  systemd.services.chatgpt-shared-tools = lib.mkIf enable {
    description = "Shared agent MCP tools through OpenAI Secure MCP Tunnel";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "agentgateway.service"
    ];
    requires = [ "agentgateway.service" ];
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
