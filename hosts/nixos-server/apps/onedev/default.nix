{ config, ... }:

let
  serverCfg = config.dotfiles.server;
  appDataRoot = serverCfg.storage.appData.root;
  serverIp = serverCfg.lan.serverIp;
in
{
  virtualisation.oci-containers.containers.onedev = {
    image = "1dev/server:latest";

    volumes = [
      "${appDataRoot}/onedev:/opt/onedev"
      "/var/run/docker.sock:/var/run/docker.sock"
    ];

    ports = [
      "${serverIp}:6610:6610"
      "${serverIp}:6611:6611"
    ];
  };
}
