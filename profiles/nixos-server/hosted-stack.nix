{
  appDataRoot,
  config,
  lib,
  pkgs,
  ...
}:

let
  secretsDir = "/root/secrets";

  appDataEditor = {
    group = "appdata-editors";
    gid = 1500;
  };

  openclawHostAdmin = {
    user = "openclaw-admin";
    privateKeyPath = "${secretsDir}/openclaw-host-admin-id_ed25519";
    privateKeyMountPath = "/run/openclaw-host-admin-id_ed25519";
  };

  appDataMode = "2770";
  snapshotMode = "0750";

  macOllamaCandidates = [
    "http://Joshans-MacBook-Pro.local:11434"
    "http://100.87.66.20:11434"
  ];

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

  backupPaths = [ appDataRoot ];
in
{
  users.groups.${appDataEditor.group}.gid = appDataEditor.gid;

  users.users.joshan.extraGroups = [ appDataEditor.group ];

  users.users.${openclawHostAdmin.user} = {
    isNormalUser = true;
    createHome = true;
    hashedPassword = "!";
    extraGroups = [ appDataEditor.group ];
  };

  security.sudo.extraRules = [
    {
      users = [ openclawHostAdmin.user ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  system.activationScripts.openclawHostAdminAuthorizedKeys = {
    deps = [ "users" ];
    text = ''
      keyFile="${openclawHostAdmin.privateKeyPath}.pub"
      home="/home/${openclawHostAdmin.user}"

      if [ -f "$keyFile" ]; then
        ${pkgs.coreutils}/bin/install -d -m 0700 -o ${openclawHostAdmin.user} -g users "$home/.ssh"
        ${pkgs.gawk}/bin/awk '{ print "from=\"127.0.0.1,::1\" " $1 " " $2 " openclaw-host-admin@nixos-server" }' "$keyFile" > "$home/.ssh/authorized_keys"
        ${pkgs.coreutils}/bin/chown ${openclawHostAdmin.user}:users "$home/.ssh/authorized_keys"
        ${pkgs.coreutils}/bin/chmod 0600 "$home/.ssh/authorized_keys"
      fi
    '';
  };

  environment.systemPackages = with pkgs; [
    acl
    curl
    docker
    iproute2
    restic
    rclone
    snapper
  ];

  virtualisation.docker.enable = true;
  virtualisation.oci-containers.backend = "docker";

  systemd.tmpfiles.rules = [
    "d ${appDataRoot} ${appDataMode} root ${appDataEditor.group} - -"
    "a+ ${appDataRoot} - - - - u:1000:rwx,g:${appDataEditor.group}:rwx,d:u:1000:rwx,d:g:${appDataEditor.group}:rwx"

    "d ${appDataRoot}/admin-tools 0755 root ${appDataEditor.group} - -"

    "d ${secretsDir} 0700 root root - -"
    "z ${openclawHostAdmin.privateKeyPath} 0400 1000 root - -"
    "z ${openclawHostAdmin.privateKeyPath}.pub 0644 root root - -"

    "v ${appDataRoot}/.snapshots ${snapshotMode} root root - -"
    "a ${appDataRoot}/.snapshots - - - - u::rwx,g::r-x,o::---,d:u::rwx,d:g::r-x,d:o::---"
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
      configFile="${appDataRoot}/openclaw/openclaw.json"

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
    unitConfig.AssertPathIsRegular = openclawHostAdmin.privateKeyPath;
    restartTriggers = [ containerUpdateTrigger ];
    after = [
      "configure-openclaw-gateway.service"
      "nginx.service"
    ];
    requires = [ "configure-openclaw-gateway.service" ];
    wants = [ "nginx.service" ];
  };

  systemd.services.openclaw-ollama-url-sync = {
    description = "Select reachable Mac Ollama endpoint for OpenClaw";
    after = [
      "network-online.target"
      "docker-openclaw.service"
    ];
    wants = [ "network-online.target" ];
    path = with pkgs; [
      coreutils
      curl
      docker
      systemd
    ];
    serviceConfig.Type = "oneshot";
    script = ''
      candidates=(
        ${lib.concatMapStringsSep "\n        " (url: ''"${url}"'') macOllamaCandidates}
      )

      mutableEnv="${appDataRoot}/admin-tools/openclaw-ollama-url-sync.env"
      if [ -f "$mutableEnv" ]; then
        # shellcheck disable=SC1090
        . "$mutableEnv"

        if [ -n "''${LAN_MDNS_URL:-}" ]; then
          candidates=("''${LAN_MDNS_URL}" "''${candidates[@]}")
        fi

        if [ -n "''${LAN_IP_URL:-}" ]; then
          candidates=("''${LAN_IP_URL}" "''${candidates[@]}")
        fi

        if [ -n "''${TS_URL:-}" ]; then
          candidates=("''${TS_URL}" "''${candidates[@]}")
        fi
      fi

      if ! docker inspect openclaw >/dev/null 2>&1; then
        echo "OpenClaw container is not running; skipping Ollama URL sync."
        exit 0
      fi

      selected=""
      for url in "''${candidates[@]}"; do
        if [ -z "$url" ]; then
          continue
        fi

        if curl -fsS --max-time 5 "''${url}/api/tags" >/tmp/openclaw-ollama-url-sync-tags.json 2>/dev/null; then
          selected="$url"
          break
        fi
      done

      if [ -z "$selected" ]; then
        echo "No reachable Ollama endpoint. Candidates were:"
        printf '  %s\n' "''${candidates[@]}"
        exit 0
      fi

      echo "Selected Ollama endpoint: $selected"

      result="$(
        docker exec \
          -e SELECTED_OLLAMA_URL="$selected" \
          --user 1000:1000 \
          openclaw node -e '
const fs = require("fs");

const url = process.env.SELECTED_OLLAMA_URL;
const configPath = "/home/node/.openclaw/openclaw.json";
const cfg = JSON.parse(fs.readFileSync(configPath, "utf8"));

let changed = false;
let count = 0;

function walk(value) {
  if (!value || typeof value !== "object") return;

  for (const key of Object.keys(value)) {
    if (key === "ollamaServerUrl") {
      if (value[key] !== url) changed = true;
      value[key] = url;
      count++;
    }

    walk(value[key]);
  }
}

walk(cfg);

if (changed) {
  const stamp = new Date().toISOString().replace(/[-:]/g, "").replace(/\..*/, "Z");
  const backupPath = configPath + ".bak-ollama-url-sync-" + stamp;
  fs.copyFileSync(configPath, backupPath);
  fs.writeFileSync(configPath, JSON.stringify(cfg, null, 2) + "\n", { mode: 0o600 });
}

console.log(changed ? "changed" : "unchanged");
console.error("ollamaServerUrl entries managed: " + count);
'
      )"

      echo "$result"

      if [ "$result" = "changed" ]; then
        echo "OpenClaw config changed; restarting docker-openclaw.service."
        systemctl restart docker-openclaw.service
      else
        echo "OpenClaw config already points at selected endpoint."
      fi
    '';
  };

  systemd.timers.openclaw-ollama-url-sync = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "2min";
      AccuracySec = "30s";
      Persistent = true;
    };
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
        "${appDataRoot}/home-assistant:/config"
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
        "${appDataRoot}/adguard/work:/opt/adguardhome/work"
        "${appDataRoot}/adguard/conf:/opt/adguardhome/conf"
      ];
      extraOptions = [
        "--network=${adguardNetwork.name}"
        "--ip=${adguardNetwork.containerIp}"
      ];
    };

    matter-server = {
      image = "ghcr.io/home-assistant-libs/python-matter-server:stable";
      pull = containerPullPolicy;
      volumes = [ "${appDataRoot}/matter-server:/data" ];
      extraOptions = [
        "--network=host"
        "--cap-add=NET_ADMIN"
        "--cap-add=NET_RAW"
      ];
    };

    n8n = {
      image = "docker.n8n.io/n8nio/n8n:latest";
      pull = containerPullPolicy;
      volumes = [ "${appDataRoot}/n8n:/home/node/.n8n" ];
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
        "${appDataRoot}/openclaw:/home/node/.openclaw"
        "${appDataRoot}/openclaw-auth:/home/node/.config/openclaw"
        "${openclawHostAdmin.privateKeyPath}:${openclawHostAdmin.privateKeyMountPath}:ro"
        "/:/host"
        "/nix/store:/nix/store:ro"
      ];
      environment = {
        OPENCLAW_DISABLE_BONJOUR = "1";
        OPENCLAW_HOST_ADMIN_SSH = "${pkgs.openssh}/bin/ssh -i ${openclawHostAdmin.privateKeyMountPath} -o StrictHostKeyChecking=accept-new ${openclawHostAdmin.user}@127.0.0.1";
      };
      environmentFiles = [ "${secretsDir}/openclaw.env" ];
      extraOptions = [
        "--network=host"
        "--group-add=${toString appDataEditor.gid}"
        "--add-host=host.docker.internal:host-gateway"
      ];
    };
  };

  services.snapper = {
    snapshotInterval = "*:0/15";
    cleanupInterval = "1h";
    persistentTimer = true;
    configs.apps = {
      SUBVOLUME = appDataRoot;
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
      "${appDataRoot}/.snapshots"
      "${appDataRoot}/home-assistant/www/media/ha-bambulab"
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