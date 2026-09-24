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
  legacyOpenclawConfigFile = "${openclawStateDir}/openclaw.json";
  openclawPackage = inputs.nix-openclaw.packages.${pkgs.stdenv.hostPlatform.system}.openclaw-gateway;
  openclawConfig = import ./config.nix;
  hmOpenclawConfig =
    config.home-manager.users.${primary.name}.home.file.".openclaw/openclaw.json".source;

  githubSecret = "${server.secretsDir}/github-self-hosted-agents.env";
  primaryHome = "${primary.homeRoot}/${primary.name}";
  mappedHome = "/run/openclaw-home";

  openclawSecrets = [
    "${server.secretsDir}/openclaw.env"
    "${server.secretsDir}/server-ai.env"
    "${server.secretsDir}/server-zdr-openrouter.env"
    "${server.secretsDir}/server-deepseek-openrouter.env"
    "${server.secretsDir}/server-free-openrouter.env"
    "${server.secretsDir}/server-openai-openrouter.env"
    githubSecret
  ];

  appDataGroup = server.storage.appData.group.name;

  openclawSudo = pkgs.writeShellScriptBin "sudo" ''
    exec /run/wrappers/bin/sudo "$@"
  '';

  openclawRepositorySkillBody = ''
    Prefer a connected macOS app node with system.run and system.which in
    /Users/joshan/.files; otherwise work directly in the server checkout:

      git -C ${primaryHome}/.files <git arguments...>
      git -C ${primaryHome}/.files/docs/infrastructure-docs <git arguments...>
      gh <arguments...>

    The service sees ${primaryHome} through bindfs, so normal writes preserve
    ${primary.name} ownership. Use sudo only for host administration.

    Use one checkout per task; inspect status first and preserve unrelated work.
    For writes, use feature branches. Never expose credentials, add a clone,
    disable host verification, or reference an unpushed submodule commit. Confirm
    before deployment or destructive operations.
  '';

in
{
  nixpkgs.overlays = [ inputs.nix-openclaw.overlays.default ];

  networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts = [ gatewayPort ];

  security.sudo.extraRules = [
    {
      users = [ openclawUser ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  fileSystems.${mappedHome} = {
    device = primaryHome;
    fsType = "fuse.bindfs";
    options = [
      "map=${primary.name}/${openclawUser}"
      "create-for-user=${primary.name}"
      "create-for-group=${config.users.users.${primary.name}.group}"
    ];
  };

  system.activationScripts.openclawNativeStateOwnership = {
    deps = [ "users" ];
    text = ''
      if [ -e ${lib.escapeShellArg legacyOpenclawConfigFile} ] && [ "$(${pkgs.coreutils}/bin/stat -c %u ${lib.escapeShellArg legacyOpenclawConfigFile})" = "$(${pkgs.coreutils}/bin/id -u ${primary.name})" ]; then
        ${pkgs.coreutils}/bin/chown -R ${openclawUser}:${appDataGroup} ${lib.escapeShellArg openclawStateDir}
      fi
      ${pkgs.coreutils}/bin/rm -rf ${lib.escapeShellArg "${openclawStateDir}/skills/repository-access"}
    '';
  };

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

  home-manager.users.${primary.name} = {
    imports = [ inputs.nix-openclaw.homeManagerModules.openclaw ];

    programs.openclaw = {
      enable = true;
      package = openclawPackage;
      toolNames = [ ];
      systemd.enable = false;
      runtimePlugins = [ "deepseek" ];
      bundledPlugins.goplaces.enable = false;
      skills = [
        {
          name = "repository-access";
          description = "Manage the server repositories and their GitHub resources.";
          mode = "inline";
          openclaw.requires.bins = [
            "git"
            "gh"
          ];
          body = openclawRepositorySkillBody;
        }
      ];
      config = openclawConfig;
    };
  };

  services.openclaw-gateway = {
    enable = true;
    package = openclawPackage;
    port = gatewayPort;
    user = openclawUser;
    group = appDataGroup;
    stateDir = openclawStateDir;
    configFile = hmOpenclawConfig;

    environment = {
      GIT_CONFIG_COUNT = "2";
      GIT_CONFIG_KEY_0 = "url.https://github.com/.insteadOf";
      GIT_CONFIG_VALUE_0 = "git@github.com:";
      GIT_CONFIG_KEY_1 = "credential.https://github.com.helper";
      GIT_CONFIG_VALUE_1 = "!${pkgs.gh}/bin/gh auth git-credential";
    };

    environmentFiles = openclawSecrets;
    execStartPre = [ "${openclawPackage}/bin/openclaw config validate" ];

    servicePath = with pkgs; [
      curl
      docker
      gh
      git
      jq
      nh
      nix
      nodejs_24
      openssh
      python3
      rsync
      systemd
      openclawSudo
    ];
  };

  systemd.services.openclaw-gateway = {
    unitConfig = {
      AssertPathExists = openclawSecrets;
      RequiresMountsFor = [ mappedHome ];
    };
    serviceConfig = {
      BindPaths = [ "${mappedHome}:${primaryHome}" ];
      UMask = "0077";
    };
  };

}
