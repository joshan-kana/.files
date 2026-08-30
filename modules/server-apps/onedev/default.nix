{ config, lib, ... }:

let
  inherit (config.dotfiles) server;
  inherit (server) lan storage;
  inherit (lan) serverIp;
  inherit (storage) appData;
in
{
  virtualisation.oci-containers.containers.onedev = {
    image = "1dev/server:latest";

    environment = {
      initial_server_url = "http://${serverIp}:6610";
      initial_ssh_root_url = "ssh://${serverIp}:6611";
    };

    volumes = [
      "${appData.root}/onedev:/opt/onedev"
      "/var/run/docker.sock:/var/run/docker.sock"
    ];

    ports = [
      "${serverIp}:6610:6610"
      "${serverIp}:6611:6611"
    ];
  };

  virtualisation.vmVariant.virtualisation.oci-containers.containers.onedev.ports = lib.mkForce [
    "6610:6610"
    "6611:6611"
  ];
}
