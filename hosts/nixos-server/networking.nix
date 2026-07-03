{
  config,
  lib,
  pkgs,
  ...
}:

let
  serverCfg = config.dotfiles.server;
  inherit (serverCfg) appDataRoot;
  inherit (serverCfg) secretsDir;
  containerCfg = serverCfg.containers;
  inherit (serverCfg) lan;

  lanPrefixLength = builtins.elemAt (lib.splitString "/" lan.subnet) 1;
  hostDns = "${lib.concatStringsSep ";" ([ lan.dns.serviceIp ] ++ lan.dns.fallbackServers)};";

  # The LAN DNS service IP should be outside the DHCP pool, or reserved so
  # another device cannot claim it.
  adguardNetwork = {
    name = "adguard_lan";
    parentInterface = lan.interface;
    inherit (lan) subnet;
    inherit (lan) gateway;
    containerIp = lan.dns.serviceIp;
    # Host-side macvlan address for reaching the AdGuard container.
    hostShimIp = lan.dns.macvlanHostShimIp;
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
      "interface-name" = lan.interface;
      autoconnect = true;
      "autoconnect-priority" = 100;
    };
    ipv4 = {
      method = "manual";
      address1 = "${lan.serverIp}/${lanPrefixLength},${lan.gateway}";
      dns = hostDns;
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
      "--hostname=${config.networking.hostName}"
      "--advertise-routes=${lan.subnet}"
      "--accept-dns=false"
    ];
    extraSetFlags = [ ];
  };

  # Keep the server's ephemeral Tailscale behaviour, but do not make
  # fresh Tailscale authentication block multi-user boot.
  #
  # The daemon still starts during boot. The auth/connect step still runs
  # automatically, but after multi-user.target so LAN boot is not held up by
  # Tailscale control-plane/auth latency.
  systemd.services.tailscaled-autoconnect = {
    after = lib.mkForce [
      "tailscaled.service"
      "multi-user.target"
    ];
    before = lib.mkForce [ "shutdown.target" ];
  };

  networking.firewall.allowedTCPPorts = [
    8123 # Home Assistant
    5678 # n8n
    5580 # Matter Server
    18789 # OpenClaw gateway reverse proxy
  ];

  networking.macvlans.adguard-shim = {
    inherit (lan) interface;
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
