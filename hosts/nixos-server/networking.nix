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
  inherit (serverCfg) lan;

  lanPrefixLength = builtins.elemAt (lib.splitString "/" lan.subnet) 1;
  hostDns = "${lib.concatStringsSep ";" ([ lan.dns.serviceIp ] ++ lan.dns.fallbackServers)};";

  dnsService = {
    user = "adguardhome";
    group = "appdata-editors";
    ip = lan.dns.serviceIp;
    dataDir = "${appDataRoot}/adguard";
    workDir = "${appDataRoot}/adguard/work";
    confDir = "${appDataRoot}/adguard/conf";
    configFile = "${appDataRoot}/adguard/conf/AdGuardHome.yaml";
  };
in
{
  # Stable machine identifier required for safe ZFS pool imports.
  networking.hostId = "f6998ba1";

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
      address2 = "${dnsService.ip}/${lanPrefixLength}";
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
    53 # Local DNS service over TCP
    8123 # Home Assistant
    5678 # n8n
    5580 # Matter Server
    18789 # OpenClaw gateway reverse proxy
    21064 # HomeKit main bridge
    21065 # HomeKit Bambu camera bridge
  ];

  networking.firewall.allowedUDPPorts = [
    53 # Local DNS service
  ];

  users.users.${dnsService.user} = {
    isSystemUser = true;
    inherit (dnsService) group;
  };

  systemd.tmpfiles.rules = [
    "d ${dnsService.dataDir} 2750 ${dnsService.user} ${dnsService.group} - -"
    "d ${dnsService.workDir} 2750 ${dnsService.user} ${dnsService.group} - -"
    "d ${dnsService.confDir} 2750 ${dnsService.user} ${dnsService.group} - -"
    "Z ${dnsService.dataDir} - ${dnsService.user} ${dnsService.group} - -"
    "z ${dnsService.configFile} 0660 ${dnsService.user} ${dnsService.group} - -"
  ];

  services.adguardhome = {
    enable = true;

    # Opens the AdGuard Home web UI port only.
    # DNS port 53 is still opened manually above.
    openFirewall = true;

    # Keep UI-edited settings, but force the critical bind settings from Nix.
    mutableSettings = true;

    # Web UI only on the dedicated LAN DNS service IP.
    # Port is intentionally omitted because the module default is 3000.
    host = dnsService.ip;

    extraArgs = [
      "--work-dir ${dnsService.workDir}"
      "--config ${dnsService.configFile}"
    ];

    settings = {
      dns = {
        # DNS only on the dedicated service IP and localhost, not 192.168.1.3.
        bind_hosts = [
          dnsService.ip
          "127.0.0.1"
        ];
        port = 53;
      };
    };
  };

  systemd.services.adguardhome = {
    after = [
      "network-online.target"
    ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = dnsService.user;
      Group = dnsService.group;

      StateDirectory = lib.mkForce "apps/adguard/conf";
      StateDirectoryMode = "2750";
      UMask = lib.mkForce "0007";

      # AdGuard writes runtime databases such as work/data/sessions.db here.
      ReadWritePaths = [ dnsService.workDir ];
    };
  };
}
