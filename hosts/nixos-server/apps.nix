{
  config,
  pkgs,
  ...
}:

let
  primaryUser = config.dotfiles.users.primary.name;
  serverCfg = config.dotfiles.server;
  inherit (serverCfg) secretsDir;
  containerCfg = serverCfg.containers;
  appDataRoot = serverCfg.storage.appData.root;

  appDataEditor = {
    group = serverCfg.storage.appData.group.name;
    gid = serverCfg.storage.appData.group.id;
  };

  openclawHostAdmin = {
    user = "openclaw-admin";
    privateKeyPath = "${secretsDir}/openclaw-host-admin-id_ed25519";
    privateKeyMountPath = "/run/openclaw-host-admin-id_ed25519";
  };

  openclawContainerUser = {
    # UID/GID used by the OpenClaw image's internal node user.
    # This is not the host primary user.
    uid = 1000;
    gid = 1000;
  };

in
{
  users.users.${primaryUser}.extraGroups = [ "docker" ];

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
  ];

  systemd.tmpfiles.rules = [
    "a+ ${appDataRoot} - - - - u:${toString openclawContainerUser.uid}:rwx,g:${appDataEditor.group}:rwx,d:u:${toString openclawContainerUser.uid}:rwx,d:g:${appDataEditor.group}:rwx"

    "d ${appDataRoot}/admin-tools 0755 root ${appDataEditor.group} - -"

    "d ${secretsDir} 0700 root root - -"
    "Z ${secretsDir} ~0700 root root - -"
    "z ${openclawHostAdmin.privateKeyPath} 0400 ${toString openclawContainerUser.uid} root - -"
    "z ${openclawHostAdmin.privateKeyPath}.pub 0644 root root - -"
  ];

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;

    appendHttpConfig = ''
      server {
        listen 127.0.0.1:11434;
        server_name ollama-proxy;

        location / {
          include /run/openclaw-ollama-proxy.conf;
          proxy_connect_timeout 2s;
          proxy_read_timeout 300s;
          proxy_send_timeout 300s;
          proxy_http_version 1.1;
          proxy_set_header Connection "";
          proxy_set_header Host $host;
        }
      }
    '';

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
          proxy_set_header X-Forwarded-User ${primaryUser};

          # OpenClaw 2026.7.1 ships script-src 'self' only, which blocks the
          # Vite/rolldown bundle's runtime eval()-based dynamic imports and
          # prevents <openclaw-app> from registering ("Control UI did not
          # start" modal). Re-emit the upstream CSP with 'unsafe-eval' added
          # to script-src; all other directives are preserved verbatim.
          proxy_hide_header Content-Security-Policy;
          add_header Content-Security-Policy "default-src 'self'; base-uri 'none'; object-src 'none'; frame-ancestors 'none'; script-src 'self' 'unsafe-eval'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; img-src 'self' data: blob:; media-src 'self' data: blob:; font-src 'self' https://fonts.gstatic.com; worker-src 'self'; connect-src 'self' ws: wss: https://api.openai.com https://tweakcn.com" always;
        '';
      };
    };
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
    restartTriggers = [ containerCfg.restartTrigger ];
  };
  systemd.services.docker-matter-server.restartTriggers = [ containerCfg.restartTrigger ];
  systemd.services.docker-n8n.restartTriggers = [ containerCfg.restartTrigger ];
  systemd.services.configure-openclaw-gateway = {
    description = "Modify OpenClaw mutable gateway config for trusted-proxy access";
    before = [ "docker-openclaw.service" ];
    path = with pkgs; [
      coreutils
      jq
    ];
    serviceConfig.Type = "oneshot";
    # NOTE on agents.defaults.* vs models.providers.*.models[]:
    #   The runtime hot-reloads agents.defaults.* changes (allowlist,
    #   primary, etc.) without bouncing the container.
    #   It does NOT hot-reload models.providers.*.models[].contextWindow
    #   / maxTokens changes because resolveContextTokensForModel uses
    #   skipRuntimeConfigLoad=Boolean(cfg), and cfg is the runtime cache
    #   populated at boot.
    #   After editing contextWindow / maxTokens / or adding new fields
    #   under providers.*.models[], run:
    #     sudo systemctl restart docker-openclaw.service
    script = ''
      configFile="${appDataRoot}/openclaw/openclaw.json"

      if [ ! -f "$configFile" ]; then
        echo "OpenClaw config does not exist yet: $configFile" >&2
        exit 1
      fi

      tmp="$(mktemp)"
      jq '
        .models = (.models // {})
        | .models.providers = (.models.providers // {})
        | .models.providers.ollama = ((.models.providers.ollama // {}) + {
            "api": "ollama",
            "baseUrl": "http://127.0.0.1:11434",
            "apiKey": "ollama-local",
            "timeoutSeconds": 300
          })
        | .models.providers.together = (
            (.models.providers.together // {})
            | .baseUrl = "https://api.together.xyz/v1"
            | .api = "openai-completions"
            | .apiKey = {
                "source": "env",
                "provider": "default",
                "id": "TOGETHER_API_KEY"
              }
            | .models = (
                (((.models // [])
                  | map(select(.id != "MiniMaxAI/MiniMax-M3"))))
                + [{
                    "id": "MiniMaxAI/MiniMax-M3",
                    "name": "MiniMax M3",
                    "reasoning": true,
                    "input": ["text", "image"],
                    "contextWindow": 1000000,
                    "maxTokens": 8192
                  }]
              )
        | .agents = (.agents // {})
        | .agents.defaults = (.agents.defaults // {})
        | .agents.defaults.model = (
            if ((.agents.defaults.model // null) | type) == "object" then
              (.agents.defaults.model + {
                "primary": "together/MiniMaxAI/MiniMax-M3"
              })
            else
              {
                "primary": "together/MiniMaxAI/MiniMax-M3"
              }
            end
          )
        | .agents.defaults.models = (
            (.agents.defaults.models // {})
            + {
              "together/*": {}
            }
          )
        | .gateway.mode = "local"
        | .gateway.bind = "loopback"
        | .gateway.port = 18789
        | .gateway.nodes = (.gateway.nodes // {})
        | .gateway.nodes.allowCommands =
            (((.gateway.nodes.allowCommands // []) - ["computer.act"]) + [
              "camera.snap",
              "camera.clip",
              "screen.record",
              "contacts.add",
              "calendar.add",
              "reminders.add",
              "health.summary"
            ] | unique)
        | .gateway.nodes.denyCommands =
            ((.gateway.nodes.denyCommands // []) - [
              "camera.snap",
              "camera.clip",
              "screen.record",
              "contacts.add",
              "calendar.add",
              "reminders.add",
              "health.summary",
              "computer.act"
            ])
        | .tools = (.tools // {})
        | .tools.alsoAllow =
            ((.tools.alsoAllow // []) - ["computer"])
        | .tools.sandbox = (.tools.sandbox // {})
        | .tools.sandbox.tools = (.tools.sandbox.tools // {})
        | .tools.sandbox.tools.alsoAllow =
            ((.tools.sandbox.tools.alsoAllow // []) - ["computer"])
        | .tools.exec = (.tools.exec // {})
        | del(.tools.exec.askFallback)
        | del(.tools.exec.security)
        | del(.tools.exec.ask)
        | .tools.exec.host = "node"
        | .tools.exec.node = "08afea100c9a0c29419893929dc89145d0d91e0638e4d008f146313da38f9966"
        | .tools.exec.mode = "full"
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
        | .plugins = (.plugins // {})
        | .plugins.allow =
            ((.plugins.allow // []) | if index("device-pair") then . else . + ["device-pair"] end)
        | .plugins.deny =
            ((.plugins.deny // []) | map(select(. != "device-pair")))
        | .plugins.entries = (.plugins.entries // {})
        | .plugins.entries."device-pair" = (.plugins.entries."device-pair" // {})
        | .plugins.entries."device-pair".enabled = true
        | .plugins.entries."device-pair".config =
            ((.plugins.entries."device-pair".config // {}) + {
              "publicUrl": "ws://192.168.1.3:18789"
            })
      ' "$configFile" > "$tmp"

      install -m 0600 -o ${toString openclawContainerUser.uid} -g ${toString openclawContainerUser.gid} "$tmp" "$configFile"
      rm -f "$tmp"
    '';
  };

  systemd.services.docker-openclaw = {
    unitConfig.AssertPathIsRegular = openclawHostAdmin.privateKeyPath;
    restartTriggers = [ containerCfg.restartTrigger ];
    after = [
      "configure-openclaw-gateway.service"
      "nginx.service"
    ];
    requires = [ "configure-openclaw-gateway.service" ];
    wants = [ "nginx.service" ];
  };

  systemd.services.openclaw-ollama-proxy = {
    description = "Write nginx upstream for the local OpenClaw Ollama proxy";
    after = [
      "network-online.target"
      "avahi-daemon.service"
    ];
    wants = [
      "network-online.target"
      "avahi-daemon.service"
    ];
    before = [ "nginx.service" ];
    path = with pkgs; [
      avahi
      coreutils
      curl
      gawk
      systemd
    ];
    serviceConfig.Type = "oneshot";
    script = ''
      conf=/run/openclaw-ollama-proxy.conf
      tmp="$(mktemp /run/openclaw-ollama-proxy.conf.XXXXXX)"
      trap 'rm -f "$tmp"' EXIT

      lan_host="Joshans-MacBook-Pro.local"
      port="11434"
      tailscale="http://100.87.66.20:11434"
      selected=""

      lan_ip="$(
        timeout 2s avahi-resolve-host-name -4 "$lan_host" 2>/dev/null \
          | awk '{ print $2; exit }' \
          || true
      )"

      if [ -n "$lan_ip" ] \
        && curl -fsS --connect-timeout 1 --max-time 2 "http://$lan_ip:$port/api/tags" >/dev/null 2>&1; then
        selected="http://$lan_ip:$port"
        echo "Using LAN Ollama upstream: $selected"
      elif curl -fsS --connect-timeout 1 --max-time 2 "$tailscale/api/tags" >/dev/null 2>&1; then
        selected="$tailscale"
        echo "Using Tailscale Ollama upstream: $selected"
      fi

      if [ -z "$selected" ] && [ -s "$conf" ]; then
        current="$(cat "$conf")"
        case "$current" in
          *".local"*)
            selected="$tailscale"
            echo "Existing proxy config used mDNS; replacing with numeric fallback: $selected"
            ;;
          *)
            echo "No reachable Ollama endpoint; keeping existing proxy config:"
            cat "$conf"
            exit 0
            ;;
        esac
      fi

      if [ -z "$selected" ]; then
        selected="$tailscale"
        echo "No reachable Ollama endpoint yet; writing numeric fallback: $selected"
      fi

      printf 'proxy_pass %s;\n' "$selected" > "$tmp"

      old="$(cat "$conf" 2>/dev/null || true)"
      new="$(cat "$tmp")"

      if [ "$new" = "$old" ]; then
        echo "Proxy config unchanged:"
        cat "$conf"
        exit 0
      fi

      install -m 0644 "$tmp" "$conf"
      echo "Wrote proxy config:"
      cat "$conf"

      if systemctl is-active --quiet nginx.service; then
        systemctl --no-block reload nginx.service
      fi
    '';
  };

  systemd.timers.openclaw-ollama-proxy = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "30s";
      OnUnitInactiveSec = "30s";
      AccuracySec = "10s";
      Persistent = true;
    };
  };
  systemd.services.nginx = {
    requires = [ "openclaw-ollama-proxy.service" ];
    after = [ "openclaw-ollama-proxy.service" ];
  };

  # Floating container tags are refreshed as part of the normal flake update
  # workflow: `nix flake update`, then `nixos-rebuild switch`.
  virtualisation.oci-containers.containers = {
    home-assistant = {
      image = "ghcr.io/home-assistant/home-assistant:stable";
      pull = containerCfg.pullPolicy;
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

    matter-server = {
      image = "ghcr.io/home-assistant-libs/python-matter-server:stable";
      pull = containerCfg.pullPolicy;
      volumes = [ "${appDataRoot}/matter-server:/data" ];
      extraOptions = [
        "--network=host"
        "--cap-add=NET_ADMIN"
        "--cap-add=NET_RAW"
      ];
    };

    n8n = {
      image = "docker.n8n.io/n8nio/n8n:latest";
      pull = containerCfg.pullPolicy;
      volumes = [ "${appDataRoot}/n8n:/home/node/.n8n" ];
      ports = [ "5678:5678" ];
      environment = {
        GENERIC_TIMEZONE = config.time.timeZone;
      };
      environmentFiles = [ "${secretsDir}/n8n.env" ];
    };

    openclaw = {
      image = "ghcr.io/openclaw/openclaw:2026.7.1";
      pull = containerCfg.pullPolicy;
      volumes = [
        "${appDataRoot}/openclaw:/home/node/.openclaw"
        "${appDataRoot}/openclaw-auth:/home/node/.config/openclaw"
        "${openclawHostAdmin.privateKeyPath}:${openclawHostAdmin.privateKeyMountPath}:ro"
        "/:/host"
        "/nix/store:/nix/store:ro"
      ];
      environment = {
        OPENCLAW_DISABLE_BONJOUR = "1";
        OLLAMA_API_KEY = "ollama-local";
        OPENCLAW_HOST_ADMIN_SSH = "${pkgs.openssh}/bin/ssh -i ${openclawHostAdmin.privateKeyMountPath} -o StrictHostKeyChecking=accept-new ${openclawHostAdmin.user}@127.0.0.1";
      };
      environmentFiles = [
        "${secretsDir}/openclaw.env"
        "${secretsDir}/server-ai.env"
      ];
      extraOptions = [
        "--network=host"
        "--group-add=${toString appDataEditor.gid}"
        "--add-host=host.docker.internal:host-gateway"
      ];
    };
  };

  # fix breville fan 3-speed patch in home assistant
  systemd.services.breville-airactive3d-3speed = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      file=/var/lib/apps/home-assistant/custom_components/tuya_local/devices/breville_airdynamic3d_fan.yaml
      [ -f "$file" ] || exit 0

      ${pkgs.gnused}/bin/sed -n \
        '/^[[:space:]]*-[[:space:]]*id:[[:space:]]*3[[:space:]]*$/,/^[[:space:]]*-[[:space:]]*id:/p' "$file" \
        | ${pkgs.gnugrep}/bin/grep -q '^[[:space:]]*max:[[:space:]]*3[[:space:]]*$' \
        && exit 0

      ${pkgs.gnused}/bin/sed -i -E \
        '/^[[:space:]]*-[[:space:]]*id:[[:space:]]*3[[:space:]]*$/,/^[[:space:]]*-[[:space:]]*id:/ s/^([[:space:]]*max:[[:space:]]*)[0-9]+/\13/' "$file"

      ${pkgs.docker}/bin/docker restart home-assistant >/dev/null || true
    '';
  };

  systemd.paths.breville-airactive3d-3speed = {
    wantedBy = [ "paths.target" ];
    pathConfig.PathChanged = "/var/lib/apps/home-assistant/custom_components/tuya_local/devices/breville_airdynamic3d_fan.yaml";
  };

}
