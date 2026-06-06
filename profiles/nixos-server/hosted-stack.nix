{
  lib,
  pkgs,
  ...
}:

let
  dataRoot = "/var/lib";
  secretsDir = "/root/secrets";

  # Change these to match the LAN before deploying. The AdGuard IP should be
  # outside the DHCP pool, or reserved so another device cannot claim it.
  adguardNetwork = {
    name = "adguard_lan";
    parentInterface = "end0";
    subnet = "192.168.1.0/24";
    gateway = "192.168.1.1";
    containerIp = "192.168.1.2";
    # Host-side macvlan address for reaching the AdGuard container.
    hostShimIp = "192.168.1.5";
  };

  resticRepository = "rclone:dropbox:Backups/nixos-home-assistant/restic";
  resticPasswordFile = "${secretsDir}/restic-password";
  rcloneConfigFile = "${secretsDir}/rclone.conf";

  backupPaths = [
    "${dataRoot}/home-assistant"
    "${dataRoot}/adguard"
    "${dataRoot}/matter-server"
    "${dataRoot}/n8n"
    "${dataRoot}/mosquitto"
    "${dataRoot}/zigbee2mqtt"
    "${dataRoot}/zwave-js-ui"
    "${dataRoot}/esphome"
    "${dataRoot}/openclaw"
    "${dataRoot}/tailscale"
  ];
in
{
  environment.systemPackages = with pkgs; [
    docker
    iproute2
    restic
    rclone
    snapper
  ];

  virtualisation.docker.enable = true;
  virtualisation.oci-containers.backend = "docker";

  systemd.tmpfiles.rules = [
    "d ${dataRoot}/home-assistant 0750 root root - -"
    "d ${dataRoot}/adguard/work 0750 root root - -"
    "d ${dataRoot}/adguard/conf 0750 root root - -"
    "d ${dataRoot}/matter-server 0750 root root - -"
    "d ${dataRoot}/n8n 0750 root root - -"
    "d ${dataRoot}/mosquitto 0750 root root - -"
    "d ${dataRoot}/zigbee2mqtt 0750 root root - -"
    "d ${dataRoot}/zwave-js-ui 0750 root root - -"
    "d ${dataRoot}/esphome 0750 root root - -"
    "d ${dataRoot}/openclaw/config 0750 root root - -"
    "d ${dataRoot}/openclaw/data 0750 root root - -"
    "d ${secretsDir} 0700 root root - -"
  ];

  services.tailscale = {
    enable = true;
    openFirewall = true;
    authKeyFile = "${secretsDir}/tailscale-authkey";
  };

  networking.firewall.allowedTCPPorts = [
    8123 # Home Assistant
    5678 # n8n
    5580 # Matter Server
    7681 # OpenClaw terminal
    18789 # OpenClaw gateway
  ];
  networking.firewall.allowedUDPPorts = [
    5353 # mDNS for Home Assistant discovery
  ];

  systemd.services.docker-network-adguard = {
    description = "Create Docker macvlan network for AdGuard Home";
    after = [
      "docker.service"
      "network-online.target"
    ];
    wants = [ "network-online.target" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [
      docker
      iproute2
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      if ! docker network inspect ${adguardNetwork.name} >/dev/null 2>&1; then
        docker network create \
          --driver macvlan \
          --subnet ${adguardNetwork.subnet} \
          --gateway ${adguardNetwork.gateway} \
          --opt parent=${adguardNetwork.parentInterface} \
          ${adguardNetwork.name}
      fi

      if ! ip link show adguard-shim >/dev/null 2>&1; then
        ip link add adguard-shim link ${adguardNetwork.parentInterface} type macvlan mode bridge
      fi

      ip addr replace ${adguardNetwork.hostShimIp}/32 dev adguard-shim
      ip link set adguard-shim up
      # Route only the AdGuard container IP through the host shim.
      ip route replace ${adguardNetwork.containerIp}/32 dev adguard-shim
    '';
  };

  systemd.services.docker-adguard = {
    after = [ "docker-network-adguard.service" ];
    requires = [ "docker-network-adguard.service" ];
  };

  virtualisation.oci-containers.containers = {
    home-assistant = {
      image = "ghcr.io/home-assistant/home-assistant:stable";
      volumes = [
        "${dataRoot}/home-assistant:/config"
        "/run/dbus:/run/dbus:ro"
      ];
      extraOptions = [ "--network=host" ];
    };

    adguard = {
      image = "adguard/adguardhome:latest";
      volumes = [
        "${dataRoot}/adguard/work:/opt/adguardhome/work"
        "${dataRoot}/adguard/conf:/opt/adguardhome/conf"
      ];
      extraOptions = [
        "--network=${adguardNetwork.name}"
        "--ip=${adguardNetwork.containerIp}"
      ];
    };

    matter-server = {
      image = "ghcr.io/home-assistant-libs/python-matter-server:stable";
      volumes = [ "${dataRoot}/matter-server:/data" ];
      extraOptions = [ "--network=host" ];
    };

    n8n = {
      image = "docker.n8n.io/n8nio/n8n:latest";
      ports = [ "5678:5678/tcp" ];
      volumes = [ "${dataRoot}/n8n:/home/node/.n8n" ];
    };

    openclaw = {
      image = "docker.io/17e0cc66/aarch64-addon-openclaw_assistant:0.5.77";
      ports = [
        "7681:7681/tcp"
        "18789:18789/tcp"
      ];
      volumes = [
        "${dataRoot}/openclaw/config:/config"
        "${dataRoot}/openclaw/data:/data"
      ];
      environmentFiles = [ "${secretsDir}/openclaw.env" ];
    };
  };

  services.snapper = {
    snapshotInterval = "15min";
    cleanupInterval = "1h";
    configs.var-lib = {
      SUBVOLUME = "/var/lib";
      TIMELINE_CREATE = true;
      TIMELINE_CLEANUP = true;
      TIMELINE_LIMIT_HOURLY = 48;
      TIMELINE_LIMIT_DAILY = 14;
      TIMELINE_LIMIT_WEEKLY = 8;
      TIMELINE_LIMIT_MONTHLY = 12;
    };
  };

  services.restic.backups.home-assistant = {
    initialize = true;
    repository = resticRepository;
    passwordFile = resticPasswordFile;
    rcloneConfigFile = rcloneConfigFile;
    paths = backupPaths;
    exclude = [
      "${dataRoot}/home-assistant/www/media/ha-bambulab"
    ];
    pruneOpts = [
      "--keep-hourly 48"
      "--keep-daily 14"
      "--keep-weekly 8"
      "--keep-monthly 12"
    ];
    timerConfig = {
      OnCalendar = "*:0/30";
      Persistent = true;
      RandomizedDelaySec = "5m";
    };
    checkOpts = [ "--read-data-subset=1G" ];
  };

  virtualisation.vmVariant = {
    services.restic.backups = lib.mkForce { };
    services.snapper.configs = lib.mkForce { };
    # VM builds do not have the real LAN interface used by the macvlan network.
    systemd.services.docker-network-adguard = lib.mkForce { };
    virtualisation.oci-containers.containers.adguard.extraOptions = lib.mkForce [ ];
    virtualisation.oci-containers.containers.adguard.ports = [
      "53:53/tcp"
      "53:53/udp"
      "3000:3000/tcp"
    ];
  };
}
