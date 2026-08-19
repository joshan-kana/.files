{ lib, ... }:

{
  virtualisation.vmVariant = {
    services.restic.backups = lib.mkForce { };
    services.snapper.configs = lib.mkForce { };
    services.immich.enable = lib.mkForce false;
    services.postgresqlBackup.enable = lib.mkForce false;

    # VM builds do not have the real Vault pool or LAN interface used by the
    # production Raspberry Pi deployment.
    systemd.services.docker-network-adguard = lib.mkForce { };

    systemd.services.docker-adguard = {
      after = lib.mkForce [ "docker.service" ];
      requires = lib.mkForce [ "docker.service" ];
    };

    virtualisation.oci-containers.containers.adguard.extraOptions = lib.mkForce [ ];
    virtualisation.oci-containers.containers.adguard.ports = [
      "53:53/tcp"
      "53:53/udp"
      "3000:3000/tcp"
    ];
  };
}
