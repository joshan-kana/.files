{ config, pkgs, ... }:

let
  serverCfg = config.dotfiles.server;
  appDataRoot = serverCfg.appDataRoot;
  secretsDir = serverCfg.secretsDir;
  containerCfg = serverCfg.containers;

  lanInterface =
    config.networking.networkmanager.ensureProfiles.profiles."wired-static".connection."interface-name";

  # Change these to match the LAN before deploying. The AdGuard IP should be
  # outside the DHCP pool, or reserved so another device cannot claim it.
  adguardNetwork = {
    name = "adguard_lan";
    parentInterface = lanInterface;
    subnet = "192.168.1.0/24";
    gateway = "192.168.1.1";
    containerIp = "192.168.1.2";
    # Host-side macvlan address for reaching the AdGuard container.
    hostShimIp = "192.168.1.5";
  };
in
{
  # Prevent ARP flux when multiple interfaces participate in the same LAN.
  # Each interface should answer ARP only for addresses assigned to itself.
  boot.kernel.sysctl = {
    "net.ipv4.conf.all.arp_ignore" = 1;
    "net.ipv4.conf.default.arp_ignore" = 1;
    "net.ipv4.conf.all.arp_announce" = 2;
    "net.ipv4.conf.default.arp_announce" = 2;
  };

  environment.systemPackages = with pkgs; [
    iproute2
  ];

  virtualisation.docker.enable = true;
  virtualisation.oci-containers.backend = "docker";

  networking.networkmanager.enable = true;
  networking.networkmanager.unmanaged = [
    "interface-name:adguard-shim"
  ];
  networking.networkmanager.ensureProfiles.profiles."wired-static" = {
    connection = {
      id = "wired-static";
      type = "ethernet";
      "interface-name" = "end0";
      autoconnect = true;
      "autoconnect-priority" = 100;
    };
    ipv4 = {
      method = "manual";
      address1 = "192.168.1.3/24,192.168.1.1";
      dns = "192.168.1.2;192.168.1.1;1.1.1.1;";
      "ignore-auto-dns" = true;
    };
    ipv6 = {
      method = "auto";
      "ignore-auto-dns" = true;
    };
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  services.tailscale = {
    enable = true;
    openFirewall = true;
    useRoutingFeatures = "server";
    authKeyFile = "${secretsDir}/tailscale-oauth-client-secret";
    authKeyParameters = {
      ephemeral = true;
      preauthorized = true;
    };
    extraDaemonFlags = [
      "--state=mem:"
    ];
    extraUpFlags = [
      "--advertise-tags=tag:nixos-server"
    ];
    extraSetFlags = [
      "--hostname=${config.networking.hostName}"
      "--advertise-routes=192.168.1.0/24"
      "--accept-dns=false"
    ];
  };

  networking.firewall.allowedTCPPorts = [
    8123 # Home Assistant
    5678 # n8n
    5580 # Matter Server
    18789 # OpenClaw gateway reverse proxy
  ];

  networking.macvlans.adguard-shim = {
    interface = lanInterface;
    mode = "bridge";
  };

  networking.interfaces.adguard-shim.ipv4.addresses = [
    {
      address = adguardNetwork.hostShimIp;
      prefixLength = 32;
    }
  ];

  networking.interfaces.adguard-shim.ipv4.routes = [
    {
      address = adguardNetwork.containerIp;
      prefixLength = 32;
    }
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
      parentInterface="${adguardNetwork.parentInterface}"

      if ! docker network inspect ${adguardNetwork.name} >/dev/null 2>&1; then
        docker network create \
          --driver macvlan \
          --subnet ${adguardNetwork.subnet} \
          --gateway ${adguardNetwork.gateway} \
          --opt parent="$parentInterface" \
          ${adguardNetwork.name}
      fi
    '';
  };

  systemd.services.docker-adguard = {
    after = [ "docker-network-adguard.service" ];
    requires = [ "docker-network-adguard.service" ];
    restartTriggers = [ containerCfg.restartTrigger ];
  };

  virtualisation.oci-containers.containers.adguard = {
    image = "adguard/adguardhome:latest";
    pull = containerCfg.pullPolicy;
    volumes = [
      "${appDataRoot}/adguard/work:/opt/adguardhome/work"
      "${appDataRoot}/adguard/conf:/opt/adguardhome/conf"
    ];
    extraOptions = [
      "--network=${adguardNetwork.name}"
      "--ip=${adguardNetwork.containerIp}"
    ];
  };
}
