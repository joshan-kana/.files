{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.dotfiles) server;
  inherit (config.dotfiles.users) primary;
  gatewayPort = 18789;
  openclawUser = "openclaw";
  openclawStateDir = "${server.storage.appData.root}/openclaw";
  openclawConfigFile = "${openclawStateDir}/openclaw.json";

  openclawPackage = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.openclaw;
  openclawPluginPaths = builtins.toJSON [
    "${openclawPackage}/lib/openclaw/extensions/codex"
    "${openclawPackage}/lib/openclaw/extensions/matrix"
    "${openclawPackage}/lib/openclaw/extensions/deepseek"
  ];
  updateOpenclawPluginPaths = pkgs.writeShellScript "update-openclaw-plugin-paths" ''
    exec ${openclawPackage}/bin/openclaw config set plugins.load.paths       ${lib.escapeShellArg openclawPluginPaths} --strict-json --replace
  '';

  openclawSecrets = [
    "${server.secretsDir}/openclaw.env"
    "${server.secretsDir}/server-ai.env"
    "${server.secretsDir}/server-zdr-openrouter.env"
    "${server.secretsDir}/server-deepseek-openrouter.env"
    "${server.secretsDir}/server-free-openrouter.env"
    "${server.secretsDir}/server-openai-openrouter.env"
  ];

  appDataGroup = server.storage.appData.group.name;

  openclawHostAdmin = {
    user = "openclaw-admin";
    privateKeySecret = "${server.secretsDir}/openclaw-host-admin-id_ed25519";
  };

  openclawHostCommand = pkgs.writeShellApplication {
    name = "openclaw-host";
    text = ''
      : "''${OPENCLAW_HOST_ADMIN_SSH:?OPENCLAW_HOST_ADMIN_SSH is not set}"
      read -r -a hostSsh <<< "$OPENCLAW_HOST_ADMIN_SSH"
      exec "''${hostSsh[@]}" "$@"
    '';
  };

  openclawGitHub = {
    apiSecret = "${server.secretsDir}/github-self-hosted-agents.env";
    privateKeySecret = "${server.secretsDir}/openclaw-github-id_ed25519";
    knownHostsFile = pkgs.writeText "openclaw-github-known-hosts" ''
      github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
    '';
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

  system.activationScripts = {
    openclawHostAdminAuthorizedKeys = {
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

    openclawNativeStateOwnership = {
      deps = [ "users" ];
      text = ''
        if [ -e ${lib.escapeShellArg openclawConfigFile} ] && [ "$(${pkgs.coreutils}/bin/stat -c %u ${lib.escapeShellArg openclawConfigFile})" = "$(${pkgs.coreutils}/bin/id -u ${primary.name})" ]; then
          ${pkgs.coreutils}/bin/chown -R ${openclawUser}:${appDataGroup} ${lib.escapeShellArg openclawStateDir}
        fi
      '';
    };

    openclawRepositorySkill = {
      deps = [ "users" ];
      text = ''
        skillDir=${lib.escapeShellArg "${openclawStateDir}/workspace/skills/repository-access"}
        ${pkgs.coreutils}/bin/install -d -m 0755 -o ${openclawUser} -g ${appDataGroup} "$skillDir"
        ${pkgs.coreutils}/bin/install -m 0644 -o ${openclawUser} -g ${appDataGroup} ${openclawRepositorySkill} "$skillDir/SKILL.md"
      '';
    };
  };

  systemd.tmpfiles.rules = [
    "d /run/openclaw-github-cli 0700 ${primary.name} users - -"
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

    systemd = {
      services.openclaw-ollama-proxy = {
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

      timers.openclaw-ollama-proxy = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "30s";
          OnUnitInactiveSec = "30s";
          AccuracySec = "10s";
          Persistent = true;
        };
      };
      services.nginx = {
        requires = [ "openclaw-ollama-proxy.service" ];
        after = [ "openclaw-ollama-proxy.service" ];
      };
    };
  };

  services.openclaw-gateway = {
    enable = true;
    package = openclawPackage;
    port = gatewayPort;
    user = openclawUser;
    group = appDataGroup;
    stateDir = openclawStateDir;
    configFile = openclawConfigFile;

    environment = {
      OPENCLAW_CONFIG_PATH = openclawConfigFile;
      OPENCLAW_HOST_ADMIN_SSH = "${pkgs.openssh}/bin/ssh -i /run/credentials/openclaw-gateway.service/openclaw-host-admin-id_ed25519 -o StrictHostKeyChecking=accept-new ${openclawHostAdmin.user}@127.0.0.1";
    };

    environmentFiles = openclawSecrets;
    execStartPre = [
      "${updateOpenclawPluginPaths}"
      "${openclawPackage}/bin/openclaw config validate"
    ];

    servicePath = with pkgs; [
      curl
      nodejs_24
      python3
      openclawRepositoryCommand
    ];
  };

  environment.etc."openclaw/openclaw.json".mode = lib.mkForce "direct-symlink";

  systemd.services.openclaw-gateway = {
    serviceConfig = {
      LoadCredential = [
        "openclaw-host-admin-id_ed25519:${openclawHostAdmin.privateKeySecret}"
      ];
      UMask = "0077";
    };
    unitConfig.AssertPathExists = openclawSecrets ++ [
      openclawConfigFile
      openclawHostAdmin.privateKeySecret
    ];
  };

}
