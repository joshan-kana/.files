{ config, lib, ... }:

let
  inherit (config.dotfiles) server;
in
{
  virtualisation.oci-containers.containers.onedev = {
    image = "1dev/server:latest";

    environment = {
      initial_server_url = "http://${server.lan.serverIp}:6610";
      initial_ssh_root_url = "ssh://${server.lan.serverIp}:6611";
    };

    volumes = [
      "${server.storage.appData.root}/onedev:/opt/onedev"
      "/var/run/docker.sock:/var/run/docker.sock"
    ];

    ports = [
      "${server.lan.serverIp}:6610:6610"
      "${server.lan.serverIp}:6611:6611"
    ];
  };

  virtualisation.vmVariant.virtualisation.oci-containers.containers.onedev.ports = lib.mkForce [
    "6610:6610"
    "6611:6611"
  ];
}
