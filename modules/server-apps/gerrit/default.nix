{ config, lib, ... }:

let
  inherit (config.dotfiles) server;
  httpPort = 8787;
  sshPort = 29418;
in
{
  services.gerrit = {
    enable = true;
    serverId = "dec01ec9-55a7-4fed-bb8b-08278d06cf51";
    listenAddress = "${server.lan.serverIp}:${toString httpPort}";

    settings = {
      gerrit.canonicalWebUrl = "http://nixos-server.home:${toString httpPort}/";
      sshd.listenAddress = "${server.lan.serverIp}:${toString sshPort}";
      sshd.advertisedAddress = "nixos-server.home:${toString sshPort}";
    };
  };

  networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts = [
    httpPort
    sshPort
  ];

  services.restic.backups.apps.paths = [ "/var/lib/gerrit" ];
  virtualisation.vmVariant.services.gerrit.enable = lib.mkForce false;
}
