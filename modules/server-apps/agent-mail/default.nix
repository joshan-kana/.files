{ config, ... }:

let
  inherit (config.dotfiles) server;
  agentMailRoot = "${server.storage.appData.root}/agent-mail";
  agentMailPort = 8765;
in
{
  virtualisation.oci-containers.containers.agent-mail = {
    image = "ghcr.io/dicklesworthstone/mcp_agent_mail_rust:latest";
    cmd = [
      "serve"
      "--no-tui"
      "--allowed-host"
      "${server.lan.serverIp}:${toString agentMailPort}"
    ];
    ports = [
      "127.0.0.1:${toString agentMailPort}:8765"
      "${server.lan.serverIp}:${toString agentMailPort}:8765"
    ];
    volumes = [ "${agentMailRoot}:/data" ];
  };

  # The upstream image runs as uid/gid 10001 and keeps all durable mailbox
  # state below /data.
  systemd.tmpfiles.rules = [
    "d ${agentMailRoot} 0700 10001 10001 - -"
  ];

  networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts = [ agentMailPort ];
}
