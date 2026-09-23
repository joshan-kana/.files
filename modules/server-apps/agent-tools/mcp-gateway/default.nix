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

  gatewayPort = 4444;
  adminPort = 15000;
  readinessPort = 15021;
  agentgateway = import ./agentgateway.nix { inherit inputs pkgs; };
  format = pkgs.formats.yaml { };
  settings = {
    config = {
      adminAddr = "${server.lan.serverIp}:${toString adminPort}";
      readinessAddr = "127.0.0.1:${toString readinessPort}";
      statsAddr = "127.0.0.1:15020";
    };
    mcp = {
      port = gatewayPort;
      targets = [
        {
          name = "agent-mail";
          mcp.host = "http://127.0.0.1:8765/mcp/";
        }
        {
          name = "github";
          mcp.host = "https://api.githubcopilot.com/mcp/";
          policies.backendAuth.key = {
            value = "$GITHUB_AUTHORIZATION";
            location.header = {
              name = "Authorization";
              prefix = "";
            };
          };
        }
        {
          name = "youtrack";
          mcp.host = "https://infrastructure.youtrack.cloud/mcp";
          policies.backendAuth.key = {
            value = "$YOUTRACK_AUTHORIZATION";
            location.header = {
              name = "Authorization";
              prefix = "";
            };
          };
        }
        {
          name = "n8n";
          mcp.host = "http://${server.lan.serverIp}:5678/mcp-server/http";
          policies.backendAuth.key = {
            value = "$N8N_AUTHORIZATION";
            location.header = {
              name = "Authorization";
              prefix = "";
            };
          };
        }
      ];
    };
  };
  configFile = format.generate "agentgateway.yaml" settings;
  validatedConfig =
    pkgs.runCommand "agentgateway-config.yaml" { nativeBuildInputs = [ agentgateway ]; }
      ''
        export GITHUB_AUTHORIZATION=validation-placeholder
        export YOUTRACK_AUTHORIZATION=validation-placeholder
        export N8N_AUTHORIZATION=validation-placeholder
        agentgateway --file ${configFile} --validate-only
        cp ${configFile} "$out"
      '';
  start = pkgs.writeShellScript "agentgateway-start" ''
    set -euo pipefail
    export GITHUB_AUTHORIZATION="$(cat "$CREDENTIALS_DIRECTORY/github-authorization")"
    export YOUTRACK_AUTHORIZATION="$(cat "$CREDENTIALS_DIRECTORY/youtrack-authorization")"
    export N8N_AUTHORIZATION="$(cat "$CREDENTIALS_DIRECTORY/n8n-authorization")"
    exec ${agentgateway}/bin/agentgateway --file ${validatedConfig}
  '';
in
{
  systemd.services.agentgateway = lib.mkIf enable {
    description = "AgentGateway MCP gateway";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "docker-n8n.service"
      "mcp-agent-mail.service"
    ];
    wants = [
      "network-online.target"
      "docker-n8n.service"
      "mcp-agent-mail.service"
    ];

    serviceConfig = {
      Type = "simple";
      DynamicUser = true;
      ExecStart = start;
      LoadCredential = [
        "github-authorization:${server.secretsDir}/agentgateway/github-authorization"
        "youtrack-authorization:${server.secretsDir}/agentgateway/youtrack-authorization"
        "n8n-authorization:${server.secretsDir}/agentgateway/n8n-authorization"
      ];
      Restart = "always";
      RestartSec = "2s";
      UMask = "0077";
    };
  };

  networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts = [ adminPort ];
}
