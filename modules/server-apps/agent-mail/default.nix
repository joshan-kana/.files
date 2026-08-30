{ config, ... }:

let
  appDataRoot = config.dotfiles.server.storage.appData.root;
  agentMailRoot = "${appDataRoot}/agent-mail";
in
{
  virtualisation.oci-containers.containers.agent-mail = {
    image = "ghcr.io/dicklesworthstone/mcp_agent_mail_rust:latest";
    ports = [ "127.0.0.1:8765:8765" ];
    volumes = [ "${agentMailRoot}:/data" ];
  };

  # The upstream image runs as uid/gid 10001 and keeps all durable mailbox
  # state below /data.
  systemd.tmpfiles.rules = [
    "d ${agentMailRoot} 0700 10001 10001 - -"
  ];
}
