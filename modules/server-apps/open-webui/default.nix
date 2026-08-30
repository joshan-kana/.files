{
  config,
  lib,
  pkgs,
  ...
}:

let
  primaryUser = config.dotfiles.users.primary.name;
  inherit (config.dotfiles) server;
  inherit (server) secretsDir;
  appDataRoot = server.storage.appData.root;
  appDataGroup = server.storage.appData.group.name;
  serverIp = server.lan.serverIp;

  openWebuiPort = 8081;
  openWebuiStateDir = "${appDataRoot}/open-webui";
  openWebuiSecret = "${secretsDir}/open-webui.env";

  computerVersion = "0.9.21";
  computerPort = 8000;
  computerRoot = "${appDataRoot}/open-webui-computer";
  computerStateDir = "${computerRoot}/state";
  computerUvCacheDir = "/var/cache/open-webui-computer/uv";

  searxPort = 8888;
  searxBaseUrl = "http://127.0.0.1:${toString searxPort}";
  searxSecret = "${secretsDir}/searxng.env";
  githubMcpPort = 8082;
  agentMailPort = 8765;
  agentMailRoot = "${appDataRoot}/agent-mail";

  hostAdmin = {
    user = "open-webui-admin";
    privateKeySecret = "${secretsDir}/open-webui-host-admin-id_ed25519";
  };
  githubSecret = "${secretsDir}/open-webui-github.env";

  hostCommand = pkgs.writeShellApplication {
    name = "open-webui-host";
    runtimeInputs = [ pkgs.openssh ];
    text = ''
      : "''${CREDENTIALS_DIRECTORY:?CREDENTIALS_DIRECTORY is not set}"
      key="$CREDENTIALS_DIRECTORY/host-admin-key"
      knownHosts="${computerRoot}/host-admin-known-hosts"

      exec ssh \
        -i "$key" \
        -o BatchMode=yes \
        -o IdentitiesOnly=yes \
        -o StrictHostKeyChecking=accept-new \
        -o UserKnownHostsFile="$knownHosts" \
        ${hostAdmin.user}@127.0.0.1 "$@"
    '';
  };

  openWebuiSync = pkgs.writeShellApplication {
    name = "open-webui-sync";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      gnugrep
      gnused
      jq
      systemd
      openssh
    ];
    text = ''
      export OPEN_WEBUI_SERVER_IP=${lib.escapeShellArg serverIp}
      export OPEN_WEBUI_SECRETS_DIR=${lib.escapeShellArg secretsDir}
      export OPEN_WEBUI_ASSET_ROOT=${lib.escapeShellArg (toString ./.)}
      export OPEN_WEBUI_PRIMARY_USER=${lib.escapeShellArg primaryUser}
      export OPEN_WEBUI_PORT=${toString openWebuiPort}
      export OPEN_WEBUI_COMPUTER_PORT=${toString computerPort}
      export OPEN_WEBUI_GITHUB_MCP_PORT=${toString githubMcpPort}
      export OPEN_WEBUI_AGENT_MAIL_PORT=${toString agentMailPort}
      export OPEN_WEBUI_GITHUB_SECRET=${lib.escapeShellArg githubSecret}
      export OPEN_WEBUI_HOST_ADMIN_KEY_SECRET=${lib.escapeShellArg hostAdmin.privateKeySecret}

      ${builtins.readFile ./open-webui-sync.sh}
    '';
  };

  # Optional convenience only: mirrors SessionWiki transcripts into the Open
  # WebUI sidebar. Native discovery/resume does not depend on this helper, so it
  # can be removed without touching Computer, SessionWiki MCP, or Agent Mail.
  nativeSessionMirror = pkgs.writeShellApplication {
    name = "open-webui-native-session-mirror";
    runtimeInputs = with pkgs; [
      openssh
      python3
    ];
    text = ''
      export OPEN_WEBUI_URL=${lib.escapeShellArg "http://${serverIp}:${toString openWebuiPort}"}
      export OPEN_WEBUI_ENV=${lib.escapeShellArg openWebuiSecret}
      export OPEN_WEBUI_NATIVE_MIRROR_STATE=${lib.escapeShellArg "${openWebuiStateDir}/native-session-mirror.json"}
      exec ${pkgs.python3}/bin/python ${./open-webui-native-session-mirror.py} "$@"
    '';
  };
in
{
  users.users.open-webui = {
    isSystemUser = true;
    group = appDataGroup;
  };

  users.users.${hostAdmin.user} = {
    isNormalUser = true;
    createHome = true;
    hashedPassword = "!";
  };

  security.sudo.extraRules = [
    {
      users = [ hostAdmin.user ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  systemd.services.open-webui-host-admin-key = {
    description = "Provision the Open WebUI localhost administration key";
    unitConfig.AssertPathExists = [ hostAdmin.privateKeySecret ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      LoadCredential = "host-admin-key:${hostAdmin.privateKeySecret}";
    };
    script = ''
      set -euo pipefail
      tmp="$(${pkgs.coreutils}/bin/mktemp)"
      trap '${pkgs.coreutils}/bin/rm -f "$tmp"' EXIT
      ${pkgs.openssh}/bin/ssh-keygen -y -f "$CREDENTIALS_DIRECTORY/host-admin-key" |
        ${pkgs.gawk}/bin/awk '{ print "from=\"127.0.0.1,::1\" " $1 " " $2 " open-webui-host-admin@nixos-server" }' > "$tmp"
      ${pkgs.coreutils}/bin/install -m 0600 -o ${hostAdmin.user} -g users "$tmp" "/home/${hostAdmin.user}/.ssh/authorized_keys"
    '';
  };

  # The native module owns Open WebUI lifecycle, migrations, DynamicUser,
  # runtime hardening and the firewall. We only choose its data/secrets policy.
  services.open-webui = {
    enable = true;
    stateDir = openWebuiStateDir;
    host = serverIp;
    port = openWebuiPort;
    environmentFile = openWebuiSecret;
    environment = {
      WEBUI_URL = "http://${serverIp}:${toString openWebuiPort}";
      WEBUI_ADMIN_NAME = "Joshan";
      ENABLE_PLUGINS = "True";
      ENABLE_WEB_SEARCH = "True";
      WEB_SEARCH_ENGINE = "searxng";
      WEB_SEARCH_RESULT_COUNT = "5";
      WEB_SEARCH_CONCURRENT_REQUESTS = "5";
      SEARXNG_QUERY_URL = "${searxBaseUrl}/search?q=<query>";
      ENABLE_USER_WEBHOOKS = "True";
    };
    openFirewall = false;
  };

  systemd.services.open-webui = {
    unitConfig.AssertPathExists = [ openWebuiSecret ];
    serviceConfig = {
      # The native module hardcodes StateDirectory=open-webui even when stateDir
      # points elsewhere. A static user keeps ownership of our backed-up custom
      # state path stable across boots while retaining the native sandbox.
      DynamicUser = lib.mkForce false;
      User = "open-webui";
      Group = appDataGroup;
      StateDirectory = lib.mkForce "";
      ProtectSystem = "strict";
      ReadWritePaths = [ openWebuiStateDir ];
    };
  };

  # SearXNG is purely a local backend for Open WebUI/Computer, so keep it on
  # loopback and let the native NixOS module own its process/config lifecycle.
  services.searx = {
    enable = true;
    environmentFile = searxSecret;
    settings = {
      server = {
        port = searxPort;
        bind_address = "127.0.0.1";
        secret_key = "$SEARX_SECRET_KEY";
        limiter = false;
        image_proxy = true;
      };
      search.formats = [
        "html"
        "json"
      ];
    };
  };

  systemd.services.searx-init.unitConfig.AssertPathExists = [ searxSecret ];

  # Computer has no native NixOS service. Pin it through uvx and keep only its
  # durable state under appData; the exact-version Python environment is a
  # disposable systemd cache rather than another managed install tree.
  systemd.services.open-webui-computer = {
    description = "Open WebUI Computer server worker";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "open-webui-host-admin-key.service"
      "sshd.service"
      "searx.service"
    ];
    wants = [
      "network-online.target"
      "searx.service"
    ];
    requires = [ "open-webui-host-admin-key.service" ];
    path = with pkgs; [
      bash
      chromium
      coreutils
      curl
      git
      jq
      nix
      openssh
      systemd
      hostCommand
    ];
    environment = {
      CPTR_DATA_DIR = computerStateDir;
      CPTR_LOG_LEVEL = "WARNING";
      ENABLE_CHAT_RECONCILE_ON_STARTUP = "true";
      SEARXNG_BASE_URL = searxBaseUrl;
      UV_CACHE_DIR = computerUvCacheDir;
      UV_PYTHON_DOWNLOADS = "never";
    };
    unitConfig.AssertPathExists = [ hostAdmin.privateKeySecret ];
    serviceConfig = {
      Type = "simple";
      User = primaryUser;
      Group = "users";
      WorkingDirectory = "/home/${primaryUser}";
      CacheDirectory = "open-webui-computer";
      CacheDirectoryMode = "0700";
      ExecStart = "${pkgs.uv}/bin/uvx --python ${pkgs.python312}/bin/python --from cptr[all]==${computerVersion} cptr run --host ${serverIp} --port ${toString computerPort} --headless";
      LoadCredential = "host-admin-key:${hostAdmin.privateKeySecret}";
      Restart = "on-failure";
      RestartSec = "5s";
      UMask = "0077";
    };
  };

  # github-mcp-server is packaged by nixpkgs but has no native service module.
  # It stores no PAT: Open WebUI supplies bearer credentials per connection.
  systemd.services.github-mcp-server = {
    description = "GitHub MCP Server (Streamable HTTP)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    environment.GITHUB_TOOLSETS = "context,repos,issues,pull_requests,actions,users";
    serviceConfig = {
      Type = "simple";
      DynamicUser = true;
      ExecStart = "${pkgs.github-mcp-server}/bin/github-mcp-server http --listen-host 127.0.0.1 --port ${toString githubMcpPort} --scope-challenge";
      Restart = "on-failure";
      RestartSec = "5s";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
      ];
    };
  };

  virtualisation.oci-containers.containers.agent-mail = {
    image = "ghcr.io/dicklesworthstone/mcp_agent_mail_rust:latest";
    ports = [ "127.0.0.1:${toString agentMailPort}:8765" ];
    volumes = [ "${agentMailRoot}:/data" ];
  };

  systemd.tmpfiles.rules = [
    # The Agent Mail image runs as uid/gid 10001 and persists mailbox state in /data.
    "d ${agentMailRoot} 0700 10001 10001 - -"
    "d /home/${hostAdmin.user}/.ssh 0700 ${hostAdmin.user} users - -"
    "d ${openWebuiStateDir} 0770 open-webui ${appDataGroup} - -"
    "Z ${openWebuiStateDir} - open-webui ${appDataGroup} - -"
    "d ${computerRoot} 0700 ${primaryUser} users - -"
    "d ${computerStateDir} 0700 ${primaryUser} users - -"
  ];

  environment.systemPackages = [
    hostCommand
    nativeSessionMirror
    openWebuiSync
  ];

  networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts = [
    openWebuiPort
    computerPort
  ];
}
