{
  config,
  inputs,
  pkgs,
  ...
}:

let
  inherit (config.dotfiles) server;
  agentgateway = import ./agentgateway.nix { inherit inputs pkgs; };
  settings = {
    config = {
      adminAddr = "127.0.0.1:15000";
      readinessAddr = "127.0.0.1:15021";
      statsAddr = "127.0.0.1:15020";
    };
    mcp = {
      port = 4444;
      policies = {
        apiKey = {
          mode = "strict";
          keys = [
            {
              key = "$CHATGPT_CLIENT_API_KEY";
              metadata.client = "chatgpt";
            }
            {
              key = "$CODEX_CLIENT_API_KEY";
              metadata.client = "codex";
            }
          ];
        };
        # ChatGPT's GitHub file reader and issue editor interrupt normal replies.
        # Codex retains both tools; ChatGPT uses shell access for issue writes.
        mcpAuthorization.rules = [
          ''apiKey.client != "chatgpt" || mcp.tool.target != "github" || (mcp.tool.name != "get_file_contents" && mcp.tool.name != "issue_write")''
        ];
      };
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
  configFile = (pkgs.formats.yaml { }).generate "agentgateway.yaml" settings;
  validatedConfig =
    pkgs.runCommand "agentgateway-config.yaml"
      {
        CHATGPT_CLIENT_API_KEY = "validation-placeholder";
        CODEX_CLIENT_API_KEY = "validation-placeholder";
        GITHUB_AUTHORIZATION = "validation-placeholder";
        YOUTRACK_AUTHORIZATION = "validation-placeholder";
        N8N_AUTHORIZATION = "validation-placeholder";
      }
      ''
        ${agentgateway}/bin/agentgateway --file ${configFile} --validate-only
        cp ${configFile} "$out"
      '';
  start = pkgs.writeShellScript "agentgateway-start" ''
    set -euo pipefail
    export CHATGPT_CLIENT_API_KEY="$(${pkgs.gnused}/bin/sed -n 's/^MCPGATEWAY_BEARER_TOKEN=//p' "$CREDENTIALS_DIRECTORY/chatgpt-client-env")"
    : "''${CHATGPT_CLIENT_API_KEY:?MCPGATEWAY_BEARER_TOKEN is not set}"
    export CODEX_CLIENT_API_KEY="$(cat "$CREDENTIALS_DIRECTORY/codex-client-api-key")"
    export GITHUB_AUTHORIZATION="$(cat "$CREDENTIALS_DIRECTORY/github-authorization")"
    export YOUTRACK_AUTHORIZATION="$(cat "$CREDENTIALS_DIRECTORY/youtrack-authorization")"
    export N8N_AUTHORIZATION="$(cat "$CREDENTIALS_DIRECTORY/n8n-authorization")"
    exec ${agentgateway}/bin/agentgateway --file ${validatedConfig}
  '';
in
{
  systemd.services.agentgateway = {
    description = "AgentGateway MCP gateway";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      DynamicUser = true;
      ExecStart = start;
      LoadCredential = [
        "chatgpt-client-env:${server.secretsDir}/chatgpt-shared-tools.env"
        "codex-client-api-key:${server.secretsDir}/agentgateway/codex-client-api-key"
        "github-authorization:${server.secretsDir}/agentgateway/github-authorization"
        "youtrack-authorization:${server.secretsDir}/agentgateway/youtrack-authorization"
        "n8n-authorization:${server.secretsDir}/agentgateway/n8n-authorization"
      ];
      Restart = "always";
      RestartSec = "2s";
      UMask = "0077";
    };
  };

  networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts = [ 4444 ];
}
