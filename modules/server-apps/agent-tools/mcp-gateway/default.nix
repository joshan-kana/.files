{
  config,
  ...
}:

let
  inherit (config.dotfiles) server;
  inherit (server.storage) appData;

  gatewayRoot = "${appData.root}/mcp-gateway";
  gatewayPort = 4444;
  gatewayUrl = "http://${server.lan.serverIp}:${toString gatewayPort}";
  gatewaySecret = "${server.secretsDir}/mcp-gateway.env";
in
{
  virtualisation.oci-containers.containers.mcp-gateway = {
    image = "ghcr.io/ibm/mcp-context-forge:v1.0.10";
    environment = {
      HOST = server.lan.serverIp;
      PORT = toString gatewayPort;
      DATABASE_URL = "sqlite:////data/mcp.db";
      APP_DOMAIN = gatewayUrl;

      MCPGATEWAY_UI_ENABLED = "true";
      MCPGATEWAY_ADMIN_API_ENABLED = "true";
      AUTO_REFRESH_SERVERS = "true";
      SECURE_COOKIES = "false";
      # This host has one ContextForge deployment; UI cookie mode must not invalidate API tokens.
      VALIDATE_TOKEN_ENVIRONMENT = "false";

      SSRF_ALLOW_LOCALHOST = "true";
      SSRF_ALLOWED_NETWORKS = builtins.toJSON [ "${server.lan.serverIp}/32" ];

      MCPGATEWAY_A2A_ENABLED = "false";
      LLMCHAT_ENABLED = "false";
    };
    environmentFiles = [ gatewaySecret ];
    volumes = [ "${gatewayRoot}:/data" ];
    extraOptions = [
      "--network=host"
      "--health-cmd=python3 -c \"import httpx,sys;sys.exit(0 if httpx.get('${gatewayUrl}/ready',timeout=5).status_code==200 else 1)\""
    ];
  };

  systemd.tmpfiles.rules = [
    "d ${gatewayRoot} 0770 agent-tools ${appData.group.name} - -"
  ];

  systemd.services.docker-mcp-gateway.unitConfig.AssertPathExists = gatewaySecret;

  networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts = [ gatewayPort ];
}
