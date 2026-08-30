{
  config,
  pkgs,
  ...
}:

let
  inherit (config.dotfiles) server;
  inherit (config.dotfiles.users) primary;
  gatewayPort = 18789;

  openclawSecrets = [
    "${server.secretsDir}/openclaw.env"
    "${server.secretsDir}/server-ai.env"
    "${server.secretsDir}/server-zdr-openrouter.env"
    "${server.secretsDir}/server-deepseek-openrouter.env"
    "${server.secretsDir}/server-free-openrouter.env"
    "${server.secretsDir}/server-openai-openrouter.env"
  ];

  appDataEditor = {
    group = server.storage.appData.group.name;
    gid = server.storage.appData.group.id;
  };

  openclawHostAdmin = {
    user = "openclaw-admin";
    privateKeySecret = "${server.secretsDir}/openclaw-host-admin-id_ed25519";
    privateKeyMountPath = "/run/openclaw-host-admin-id_ed25519";
  };

  openclawHostCommand = pkgs.writeShellApplication {
    name = "openclaw-host";
    runtimeInputs = with pkgs; [ bash ];
    text = ''
      : "''${OPENCLAW_HOST_ADMIN_SSH:?OPENCLAW_HOST_ADMIN_SSH is not set}"
      read -r -a hostSsh <<< "$OPENCLAW_HOST_ADMIN_SSH"
      exec "''${hostSsh[@]}" "$@"
    '';
  };

  openclawGitHub = {
    apiSecret = "${server.secretsDir}/openclaw-github.env";
    privateKeySecret = "${server.secretsDir}/openclaw-github-id_ed25519";
    knownHostsFile = pkgs.writeText "openclaw-github-known-hosts" ''
      github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
    '';
  };

  openclawContainerUser = {
    # UID/GID used by the OpenClaw image's internal node user.
    # This is not the host primary user.
    uid = 1000;
    gid = 1000;
  };

  openclawRepositoryHost = pkgs.writeShellApplication {
    name = "openclaw-repository-host";
    runtimeInputs = with pkgs; [
      coreutils
      gh
      git
      openssh
      util-linux
    ];
    text = ''
      die() { echo "$*" >&2; exit 1; }
      [ "$(${pkgs.coreutils}/bin/id -u)" -eq 0 ] ||
        die "openclaw-repository-host must run as root"

      primaryEnv=(runuser -u ${primary.name} -- env -i HOME=/home/${primary.name}
        USER=${primary.name} LOGNAME=${primary.name} PATH="$PATH")

      operation="''${1:-}"; [ "$#" -eq 0 ] || shift

      case "$operation" in
        gh)
          [ -r ${openclawGitHub.apiSecret} ] ||
            die "GitHub API credentials are not provisioned: ${openclawGitHub.apiSecret}"

          unset GH_TOKEN
          # shellcheck disable=SC1091
          source ${openclawGitHub.apiSecret}
          : "''${GH_TOKEN:?${openclawGitHub.apiSecret} must define GH_TOKEN}"

          exec "''${primaryEnv[@]}" \
            GH_TOKEN="$GH_TOKEN" \
            GH_CONFIG_DIR=/run/openclaw-github-cli \
            gh "$@"
          ;;
        git)
          repository="''${1:-}"; [ "$#" -eq 0 ] || shift

          case "$repository" in
            files) checkout=/home/${primary.name}/.files ;;
            infrastructure-docs) checkout=/home/${primary.name}/.files/docs/infrastructure-docs ;;
            *)
              die "usage: openclaw-repository-host git {files|infrastructure-docs} <git arguments...>"
              ;;
          esac

          [ -r ${openclawGitHub.privateKeySecret} ] ||
            die "GitHub SSH key is not provisioned: ${openclawGitHub.privateKeySecret}"

          agentDir="$(mktemp -d /run/openclaw-git-agent.XXXXXX)"
          trap 'ssh-agent -k >/dev/null 2>&1 || true; rm -rf "$agentDir"' EXIT
          install -d -m 0700 -o ${primary.name} -g users "$agentDir"

          eval "$("''${primaryEnv[@]}" ssh-agent -a "$agentDir/agent.sock" -s)" >/dev/null

          ssh-add ${openclawGitHub.privateKeySecret} >/dev/null 2>&1 ||
            die "Failed to load the OpenClaw GitHub SSH key"

          publicIdentity="$agentDir/id_ed25519.pub"
          ssh-add -L | install -m 0644 -o ${primary.name} -g users /dev/stdin "$publicIdentity" ||
            die "Failed to write the OpenClaw GitHub public identity"

          gitSshCommand="ssh -o BatchMode=yes -o IdentitiesOnly=yes -o IdentityFile=$publicIdentity -o StrictHostKeyChecking=yes -o UserKnownHostsFile=${openclawGitHub.knownHostsFile}"
          "''${primaryEnv[@]}" \
            GIT_SSH_COMMAND="$gitSshCommand" \
            SSH_AUTH_SOCK="$SSH_AUTH_SOCK" \
            GIT_TERMINAL_PROMPT=0 \
            git -C "$checkout" "$@"
          ;;
        *)
          echo "usage: openclaw-repository-host {gh|git} ..." >&2
          exit 2
          ;;
      esac
    '';
  };

  openclawRepositoryCommand = pkgs.writeShellApplication {
    name = "openclaw-repository";
    runtimeInputs = with pkgs; [ bash ];
    text = ''
      remoteCommand="sudo ${openclawRepositoryHost}/bin/openclaw-repository-host"
      remoteArgs=
      [ "$#" -eq 0 ] || printf -v remoteArgs ' %q' "$@"

      exec ${openclawHostCommand}/bin/openclaw-host "$remoteCommand$remoteArgs"
    '';
  };

  openclawRepositorySkill = pkgs.writeText "openclaw-repository-access-skill" ''
    ---
    name: repository-access
    description: Manage the server repositories and their GitHub resources.
    metadata: { "openclaw": { "requires": { "bins": ["openclaw-repository"] } } }
    ---

    Prefer a connected macOS app node with `system.run` and `system.which` in
    `/Users/joshan/.files`; otherwise use the server wrappers:

    ```sh
    openclaw-repository git files <git arguments...>
    openclaw-repository git infrastructure-docs <git arguments...>
    openclaw-repository gh <gh arguments...>
    ```

    Use one checkout per task; inspect status first and preserve unrelated work.
    For writes, use feature branches. Never expose credentials, add a clone,
    disable host verification, or reference an unpushed submodule commit. Confirm
    before deployment or destructive operations.
  '';

in
{
  networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts = [ gatewayPort ];

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
      keyFile="${openclawHostAdmin.privateKeySecret}.pub"
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
    gh
    openclawRepositoryHost
  ];

  systemd.tmpfiles.rules = [
    "a+ ${server.storage.appData.root} - - - - u:${toString openclawContainerUser.uid}:rwx,g:${appDataEditor.group}:rwx,d:u:${toString openclawContainerUser.uid}:rwx,d:g:${appDataEditor.group}:rwx"

    "d ${server.storage.appData.root}/admin-tools 0755 root ${appDataEditor.group} - -"
    "d ${server.storage.appData.root}/openclaw/workspace/skills 0755 ${toString openclawContainerUser.uid} ${toString openclawContainerUser.gid} - -"
    "d ${server.storage.appData.root}/openclaw/workspace/skills/repository-access 0755 ${toString openclawContainerUser.uid} ${toString openclawContainerUser.gid} - -"
    "d /run/openclaw-github-cli 0700 ${primary.name} users - -"

    "z ${openclawGitHub.apiSecret} 0400 root root - -"
    "z ${openclawGitHub.privateKeySecret} 0400 root root - -"
    "z ${openclawGitHub.privateKeySecret}.pub 0644 root root - -"
    "z ${openclawHostAdmin.privateKeySecret} 0400 ${toString openclawContainerUser.uid} root - -"
    "z ${openclawHostAdmin.privateKeySecret}.pub 0644 root root - -"
  ];

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;

    virtualHosts.openclaw = {
      listen = [
        {
          addr = server.lan.serverIp;
          port = gatewayPort;
        }
      ];

      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString gatewayPort}";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-User ${primary.name};

          # OpenClaw ships script-src 'self' only, which blocks the Vite/rolldown
          # bundle's runtime eval()-based dynamic imports and prevents
          # <openclaw-app> from registering ("Control UI did not start" modal).
          # Re-emit the upstream CSP with 'unsafe-eval' added to script-src; all
          # other directives are preserved verbatim.
          proxy_hide_header Content-Security-Policy;
          add_header Content-Security-Policy "default-src 'self'; base-uri 'none'; object-src 'none'; frame-ancestors 'none'; script-src 'self' 'unsafe-eval'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; img-src 'self' data: blob:; media-src 'self' data: blob:; font-src 'self' https://fonts.gstatic.com; worker-src 'self'; connect-src 'self' ws: wss: https://api.openai.com https://tweakcn.com" always;
        '';
      };
    };
  };

  systemd.services.configure-openclaw-gateway = {
    description = "Modify OpenClaw mutable gateway config for trusted-proxy access";
    before = [ "docker-openclaw.service" ];
    path = with pkgs; [
      coreutils
      jq
    ];
    serviceConfig.Type = "oneshot";
    script = ''
      configFile="${server.storage.appData.root}/openclaw/openclaw.json"

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
          )
        | .models.providers.deepseek = (
            (.models.providers.deepseek // {})
            | .baseUrl = "https://api.deepseek.com"
            | .api = "openai-completions"
            | .apiKey = {
                "source": "env",
                "provider": "default",
                "id": "DEEPSEEK_API_KEY"
              }
          )
        | .models.providers."openrouter-zdr" = (
            (.models.providers."openrouter-zdr" // {})
            | .baseUrl = "https://openrouter.ai/api/v1"
            | .api = "openai-completions"
            | .apiKey = {
                "source": "env",
                "provider": "default",
                "id": "OPENROUTER_ZDR_API_KEY"
              }
            | .timeoutSeconds = 300
            | .models = [
                {
                  "id": "minimax/minimax-m3",
                  "name": "MiniMax M3 — OpenRouter ZDR",
                  "reasoning": true,
                  "input": ["text", "image"],
                  "contextWindow": 1048576,
                  "maxTokens": 131072
                },
                {
                  "id": "z-ai/glm-5.2",
                  "name": "GLM 5.2 — OpenRouter ZDR",
                  "reasoning": true,
                  "input": ["text"],
                  "contextWindow": 1048576,
                  "maxTokens": 131072
                }
              ]
          )
        | .models.providers."openrouter-deepseek" = (
            (.models.providers."openrouter-deepseek" // {})
            | .baseUrl = "https://openrouter.ai/api/v1"
            | .api = "openai-completions"
            | .apiKey = {
                "source": "env",
                "provider": "default",
                "id": "OPENROUTER_DEEPSEEK_API_KEY"
              }
            | .timeoutSeconds = 300
            | .models = [
                {
                  "id": "deepseek/deepseek-v4-flash-latest",
                  "name": "DeepSeek V4 Flash (latest) — OpenRouter non-ZDR",
                  "reasoning": true,
                  "input": ["text"],
                  "contextWindow": 1048576,
                  "maxTokens": 65536
                },
                {
                  "id": "deepseek/deepseek-v4-pro",
                  "name": "DeepSeek V4 Pro — OpenRouter non-ZDR",
                  "reasoning": true,
                  "input": ["text"],
                  "contextWindow": 1048576,
                  "maxTokens": 393216
                }
              ]
          )
        | .models.providers."openrouter-free" = (
            (.models.providers."openrouter-free" // {})
            | .baseUrl = "https://openrouter.ai/api/v1"
            | .api = "openai-completions"
            | .apiKey = {
                "source": "env",
                "provider": "default",
                "id": "OPENROUTER_FREE_API_KEY"
              }
            | .timeoutSeconds = 300
            | .models = [
                {
                  "id": "google/gemma-4-31b-it:free",
                  "name": "Gemma 4 31B (free) — FREE / NON-SENSITIVE",
                  "reasoning": true,
                  "input": ["text"],
                  "contextWindow": 262144,
                  "maxTokens": 16384
                },
                {
                  "id": "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free",
                  "name": "Nemotron 3 Nano Omni (free) — FREE / NON-SENSITIVE",
                  "reasoning": true,
                  "input": ["text"],
                  "contextWindow": 256000,
                  "maxTokens": 65536
                },
                {
                  "id": "nvidia/nemotron-3-ultra-550b-a55b:free",
                  "name": "Nemotron 3 Ultra (free) — FREE / NON-SENSITIVE",
                  "reasoning": true,
                  "input": ["text"],
                  "contextWindow": 1000000,
                  "maxTokens": 65536
                },
                {
                  "id": "nvidia/nemotron-3-super-120b-a12b:free",
                  "name": "Nemotron 3 Super (free) — FREE / NON-SENSITIVE",
                  "reasoning": true,
                  "input": ["text"],
                  "contextWindow": 262144,
                  "maxTokens": 65536
                },
                {
                  "id": "openai/gpt-oss-20b:free",
                  "name": "GPT-OSS 20B (free) — FREE / NON-SENSITIVE",
                  "reasoning": true,
                  "input": ["text"],
                  "contextWindow": 131072,
                  "maxTokens": 16384
                }
              ]
          )
        | .models.providers."openrouter-openai" = (
            (.models.providers."openrouter-openai" // {})
            | .baseUrl = "https://openrouter.ai/api/v1"
            | .api = "openai-completions"
            | .apiKey = {
                "source": "env",
                "provider": "default",
                "id": "OPENROUTER_OPENAI_API_KEY"
              }
            | .timeoutSeconds = 300
            | .models = [
                {
                  "id": "openai/gpt-5.5",
                  "name": "GPT-5.5 — OpenRouter OpenAI",
                  "reasoning": true,
                  "input": ["text", "image"],
                  "contextWindow": 1048576,
                  "maxTokens": 131072
                },
                {
                  "id": "openai/gpt-5.6-luna",
                  "name": "GPT-5.6 Luna — OpenRouter OpenAI",
                  "reasoning": true,
                  "input": ["text", "image"],
                  "contextWindow": 1048576,
                  "maxTokens": 131072
                },
                {
                  "id": "openai/gpt-5.6-luna-pro",
                  "name": "GPT-5.6 Luna Pro — OpenRouter OpenAI",
                  "reasoning": true,
                  "input": ["text", "image"],
                  "contextWindow": 1048576,
                  "maxTokens": 131072
                },
                {
                  "id": "openai/gpt-5.6-sol",
                  "name": "GPT-5.6 Sol — OpenRouter OpenAI",
                  "reasoning": true,
                  "input": ["text", "image"],
                  "contextWindow": 1048576,
                  "maxTokens": 131072
                },
                {
                  "id": "openai/gpt-5.6-sol-pro",
                  "name": "GPT-5.6 Sol Pro — OpenRouter OpenAI",
                  "reasoning": true,
                  "input": ["text", "image"],
                  "contextWindow": 1048576,
                  "maxTokens": 131072
                }
              ]
          )
        | .agents = (.agents // {})
        | .agents.defaults = (.agents.defaults // {})
        | .agents.defaults.model = (
            if ((.agents.defaults.model // null) | type) == "object" then
              (.agents.defaults.model + {
                "primary": "openrouter-zdr/minimax/minimax-m3",
                "fallbacks": []
              })
            else
              {
                "primary": "openrouter-zdr/minimax/minimax-m3",
                "fallbacks": []
              }
            end
          )
        | .agents.defaults.models = (
            (.agents.defaults.models // {})
            + {
              "together/*": {},
              "deepseek/*": {},
              "openrouter-zdr/minimax/minimax-m3": {
                "alias": "OR ZDR MiniMax M3"
              },
              "openrouter-zdr/z-ai/glm-5.2": {
                "alias": "OR ZDR GLM 5.2"
              },
              "openrouter-deepseek/deepseek/deepseek-v4-flash-latest": {
                "alias": "OR DeepSeek V4 Flash (latest, non-ZDR)"
              },
              "openrouter-deepseek/deepseek/deepseek-v4-pro": {
                "alias": "OR DeepSeek V4 Pro (non-ZDR)"
              },
              "openrouter-free/google/gemma-4-31b-it:free": {
                "alias": "OR Free Gemma 4 31B (FREE / NON-SENSITIVE)"
              },
              "openrouter-free/nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free": {
                "alias": "OR Free Nemotron 3 Nano Omni (FREE / NON-SENSITIVE)"
              },
              "openrouter-free/nvidia/nemotron-3-ultra-550b-a55b:free": {
                "alias": "OR Free Nemotron 3 Ultra (FREE / NON-SENSITIVE)"
              },
              "openrouter-free/nvidia/nemotron-3-super-120b-a12b:free": {
                "alias": "OR Free Nemotron 3 Super (FREE / NON-SENSITIVE)"
              },
              "openrouter-free/openai/gpt-oss-20b:free": {
                "alias": "OR Free GPT-OSS 20B (FREE / NON-SENSITIVE)"
              }
            }
          )
        | .gateway.mode = "local"
        | .gateway.bind = "loopback"
        | .gateway.port = ${toString gatewayPort}
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
        | .tools.exec.host = "gateway"
        | del(.tools.exec.node)
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
            ((.gateway.controlUi.allowedOrigins // []) + ["http://${server.lan.serverIp}:${toString gatewayPort}"] | unique)
        | .plugins = (.plugins // {})
        | .plugins.allow =
            ((.plugins.allow // []) + ["codex", "openai", "ollama", "matrix", "device-pair", "deepseek"] | unique)
        | .plugins.deny =
            ((.plugins.deny // []) | map(select(. != "device-pair")))
        | .plugins.entries = (.plugins.entries // {})
        | .plugins.entries."device-pair" = (.plugins.entries."device-pair" // {})
        | .plugins.entries."device-pair".enabled = true
        | .plugins.entries."device-pair".config =
            ((.plugins.entries."device-pair".config // {}) + {
              "publicUrl": "ws://${server.lan.serverIp}:${toString gatewayPort}"
            })
      ' "$configFile" > "$tmp"

      install -m 0600 -o ${toString openclawContainerUser.uid} -g ${toString openclawContainerUser.gid} "$tmp" "$configFile"
      rm -f "$tmp"
    '';
  };

  ollamaMacBridge = _: {
    services.nginx.appendHttpConfig = ''
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
  };

  systemd.services.docker-openclaw = {
    after = [
      "configure-openclaw-gateway.service"
      "nginx.service"
    ];
    requires = [ "configure-openclaw-gateway.service" ];
    wants = [ "nginx.service" ];
  };

  systemd.services.docker-openclaw.unitConfig.AssertPathExists = openclawSecrets ++ [
    openclawHostAdmin.privateKeySecret
  ];

  # Server OCI containers. Images are declared as plain upstream `repository:tag`
  # sources; the global `container-image-locking.nix` module appends the matching
  # locked digest at evaluation time, so these definitions stay in native NixOS
  # OCI-container syntax.
  virtualisation.oci-containers.containers = {
    openclaw = {
      image = "ghcr.io/openclaw/openclaw:latest";

      volumes = [
        "${server.storage.appData.root}/openclaw:/home/node/.openclaw"
        "${server.storage.appData.root}/openclaw-auth:/home/node/.config/openclaw"
        "${openclawHostAdmin.privateKeySecret}:${openclawHostAdmin.privateKeyMountPath}:ro"
        "${openclawHostCommand}/bin/openclaw-host:/usr/local/bin/openclaw-host:ro"
        "${openclawRepositoryCommand}/bin/openclaw-repository:/usr/local/bin/openclaw-repository:ro"
        "${openclawRepositorySkill}:/home/node/.openclaw/workspace/skills/repository-access/SKILL.md:ro"
        "/:/host"
        "/nix/store:/nix/store:ro"
      ];

      environment = {
        OPENCLAW_DISABLE_BONJOUR = "1";
        OLLAMA_API_KEY = "ollama-local";
        NODE_OPTIONS = "--dns-result-order=ipv4first";
        OPENCLAW_HOST_ADMIN_SSH = "${pkgs.openssh}/bin/ssh -i ${openclawHostAdmin.privateKeyMountPath} -o StrictHostKeyChecking=accept-new ${openclawHostAdmin.user}@127.0.0.1";
      };
      environmentFiles = openclawSecrets;

      extraOptions = [
        "--network=host"
        "--group-add=${toString appDataEditor.gid}"
        "--add-host=host.docker.internal:host-gateway"
      ];
    };
  };

}
