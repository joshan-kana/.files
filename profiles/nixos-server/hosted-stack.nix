{
  appDataRoot,
  config,
  lib,
  pkgs,
  ...
}:

let
  dataRoot = appDataRoot;
  secretsDir = "/root/secrets";
  lanInterface =
    config.networking.networkmanager.ensureProfiles.profiles."wired-static".connection."interface-name";

  # Floating container tags are refreshed as part of the normal flake update
  # workflow: `nix flake update`, then `nixos-rebuild switch`.
  containerPullPolicy = "always";
  containerUpdateTrigger = builtins.path {
    path = ../../flake.lock;
    name = "nixos-server-flake-lock";
  };

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

  resticRepository = "rclone:dropbox:Archives/Backups/nixos-server";
  resticPasswordFile = "${secretsDir}/restic-password";
  rcloneConfigFile = "${secretsDir}/rclone.conf";

  backupPaths = [ dataRoot ];
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
    "d ${dataRoot} 0750 root root - -"
    "d ${dataRoot}/home-assistant 0750 root root - -"
    "d ${dataRoot}/adguard/work 0750 root root - -"
    "d ${dataRoot}/adguard/conf 0750 root root - -"
    "d ${dataRoot}/matter-server 0750 root root - -"
    "d ${dataRoot}/n8n 0750 1000 1000 - -"
    "d ${dataRoot}/mosquitto 0750 root root - -"
    "d ${dataRoot}/zigbee2mqtt 0750 root root - -"
    "d ${dataRoot}/zwave-js-ui 0750 root root - -"
    "d ${dataRoot}/esphome 0750 root root - -"
    "d ${dataRoot}/openclaw 0750 1000 1000 - -"
    "d ${dataRoot}/openclaw-auth 0750 1000 1000 - -"
    "d ${secretsDir} 0700 root root - -"
    "v ${dataRoot}/.snapshots 0750 root root - -"
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

  services.tailscale = {
    enable = true;
    openFirewall = true;
    authKeyFile = "${secretsDir}/tailscale-authkey";
    extraSetFlags = [ "--accept-dns=false" ];
  };

  networking.firewall.allowedTCPPorts = [
    8123 # Home Assistant
    5678 # n8n
    5580 # Matter Server
    18789 # OpenClaw gateway reverse proxy
  ];
  networking.firewall.allowedUDPPorts = [
    5353 # mDNS for Home Assistant discovery
  ];

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    virtualHosts.openclaw = {
      listen = [
        {
          addr = "192.168.1.3";
          port = 18789;
        }
      ];

      locations."/" = {
        proxyPass = "http://127.0.0.1:18789";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-User joshan;
        '';
      };
    };
  };

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

  systemd.services.docker-home-assistant = {
    after = [
      "bluetooth.service"
      "dbus.service"
    ];
    wants = [
      "bluetooth.service"
      "dbus.service"
    ];
    restartTriggers = [ containerUpdateTrigger ];
  };
  systemd.services.docker-matter-server.restartTriggers = [ containerUpdateTrigger ];
  systemd.services.docker-n8n.restartTriggers = [ containerUpdateTrigger ];
  systemd.services.configure-openclaw-gateway = {
    description = "Modify OpenClaw mutable gateway config for trusted-proxy access";
    before = [ "docker-openclaw.service" ];
    path = with pkgs; [
      coreutils
      jq
    ];
    serviceConfig.Type = "oneshot";
    script = ''
      configFile="${dataRoot}/openclaw/openclaw.json"

      if [ ! -f "$configFile" ]; then
        echo "OpenClaw config does not exist yet: $configFile" >&2
        exit 1
      fi

      tmp="$(mktemp)"
      jq '
        .gateway.mode = "local"
        | .gateway.bind = "loopback"
        | .gateway.port = 18789
        | .gateway.trustedProxies = ["127.0.0.1", "::1"]
        | .gateway.auth = {
            "mode": "trusted-proxy",
            "trustedProxy": {
              "userHeader": "x-forwarded-user",
              "requiredHeaders": [
                "x-forwarded-proto",
                "x-forwarded-host"
              ],
              "allowLoopback": true
            }
          }
        | del(.gateway.auth.token)
        | del(.gateway.auth.password)
        | .gateway.controlUi.allowInsecureAuth = true
        | .gateway.controlUi.dangerouslyDisableDeviceAuth = true
        | .gateway.controlUi.allowedOrigins =
            ((.gateway.controlUi.allowedOrigins // []) + ["http://192.168.1.3:18789"] | unique)
      ' "$configFile" > "$tmp"

      install -m 0600 -o 1000 -g 1000 "$tmp" "$configFile"
      rm -f "$tmp"
    '';
  };

  systemd.services.docker-openclaw = {
    restartTriggers = [ containerUpdateTrigger ];
    after = [
      "configure-openclaw-gateway.service"
      "nginx.service"
    ];
    requires = [ "configure-openclaw-gateway.service" ];
    wants = [ "nginx.service" ];
  };

  systemd.services.docker-adguard = {
    after = [ "docker-network-adguard.service" ];
    requires = [ "docker-network-adguard.service" ];
    restartTriggers = [ containerUpdateTrigger ];
  };

  virtualisation.oci-containers.containers = {
    home-assistant = {
      image = "ghcr.io/home-assistant/home-assistant:stable";
      pull = containerPullPolicy;
      volumes = [
        "${dataRoot}/home-assistant:/config"
        "/run/dbus:/run/dbus:ro"
      ];
      extraOptions = [
        "--network=host"
        "--cap-add=NET_ADMIN"
        "--cap-add=NET_RAW"
      ];
    };

    adguard = {
      image = "adguard/adguardhome:latest";
      pull = containerPullPolicy;
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
      pull = containerPullPolicy;
      volumes = [ "${dataRoot}/matter-server:/data" ];
      extraOptions = [
        "--network=host"
        "--cap-add=NET_ADMIN"
        "--cap-add=NET_RAW"
      ];
    };

    n8n = {
      image = "docker.n8n.io/n8nio/n8n:latest";
      pull = containerPullPolicy;
      volumes = [ "${dataRoot}/n8n:/home/node/.n8n" ];
      ports = [ "5678:5678" ];
      environment = {
        GENERIC_TIMEZONE = config.time.timeZone;
      };
      environmentFiles = [ "${secretsDir}/n8n.env" ];
    };

    openclaw = {
      image = "ghcr.io/openclaw/openclaw:latest";
      pull = containerPullPolicy;
      volumes = [
        "${dataRoot}/openclaw:/home/node/.openclaw"
        "${dataRoot}/openclaw-auth:/home/node/.config/openclaw"
        "/:/host"
        "/var/run/docker.sock:/var/run/docker.sock"
      ];
      environment = {
        OPENCLAW_DISABLE_BONJOUR = "1";
      };
      environmentFiles = [ "${secretsDir}/openclaw.env" ];
      extraOptions = [
        "--network=host"
        "--add-host=host.docker.internal:host-gateway"
      ];
    };
  };

  services.snapper = {
    snapshotInterval = "*:0/15";
    cleanupInterval = "1h";
    persistentTimer = true;
    configs.apps = {
      SUBVOLUME = dataRoot;
      FSTYPE = "btrfs";
      TIMELINE_CREATE = true;
      TIMELINE_CLEANUP = true;
      TIMELINE_LIMIT_HOURLY = 48;
      TIMELINE_LIMIT_DAILY = 14;
      TIMELINE_LIMIT_WEEKLY = 8;
      TIMELINE_LIMIT_MONTHLY = 12;
    };
  };

  services.restic.backups.apps = {
    initialize = true;
    repository = resticRepository;
    passwordFile = resticPasswordFile;
    rcloneConfigFile = rcloneConfigFile;
    paths = backupPaths;
    exclude = [
      "${dataRoot}/.snapshots"
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
