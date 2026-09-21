{ config, ... }:

let
  inherit (config.dotfiles) server;
  inherit (server.storage) appData;
  agentMailRoot = "${appData.root}/agent-mail";
  agentMailPort = 8765;
in
{
  virtualisation.oci-containers.containers.agent-mail = {
    image = "ghcr.io/dicklesworthstone/mcp_agent_mail_rust:latest";
    cmd = [
      "serve"
      "--no-tui"
    ];
    environment = {
      HTTP_HOST = "0.0.0.0";
      HTTP_PORT = toString agentMailPort;
      HTTP_ALLOWED_HOSTS = server.lan.serverIp;
    };
    volumes = [ "${agentMailRoot}:/data" ];
    extraOptions = [ "--network=host" ];
  };

  systemd.tmpfiles.rules = [
    "d ${agentMailRoot} 0700 agent-tools agent-tools - -"
  ];

  networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts = [ agentMailPort ];
}
