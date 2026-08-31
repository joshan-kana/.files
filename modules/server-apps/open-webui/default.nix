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
  inherit (server.storage) appData;

  openWebuiPort = 8081;
  openWebuiStateDir = "${appData.root}/open-webui";
  openWebuiSecret = "${server.secretsDir}/open-webui.env";

  computerVersion =
    (builtins.fromTOML (builtins.readFile "${inputs.computer}/pyproject.toml")).project.version;
  computerPort = 8000;
  computerRoot = "${appData.root}/open-webui-computer";
  computerStateDir = "${computerRoot}/state";
  computerGithubSecret = "${server.secretsDir}/open-webui-github.env";

  searxPort = 8888;
  searxSecret = "${server.secretsDir}/searxng.env";

  hostAdmin = {
    user = "open-webui-admin";
    privateKeySecret = "${server.secretsDir}/open-webui-host-admin-id_ed25519";
    runtimeDirectory = "open-webui-host-admin";
  };

  hostCommand = pkgs.writeShellApplication {
    name = "open-webui-host";
    runtimeInputs = [ pkgs.openssh ];
    text = ''
      : "''${CREDENTIALS_DIRECTORY:?CREDENTIALS_DIRECTORY is not set}"

      exec ssh \
        -i "$CREDENTIALS_DIRECTORY/host-admin-key" \
        -o BatchMode=yes \
        -o IdentitiesOnly=yes \
        -o StrictHostKeyChecking=accept-new \
        -o UserKnownHostsFile=/run/open-webui-computer/host-admin-known-hosts \
        ${hostAdmin.user}@127.0.0.1 "$@"
    '';
  };

  computerStart = pkgs.writeShellScript "open-webui-computer-start" ''
    set -euo pipefail
    umask 0077

    setupToken="$(${pkgs.coreutils}/bin/od -An -N32 -tx1 /dev/urandom | ${pkgs.coreutils}/bin/tr -d ' \n')"
    printf '%s\n' "$setupToken" > "$RUNTIME_DIRECTORY/setup-token"
    ${pkgs.coreutils}/bin/chmod 0400 "$RUNTIME_DIRECTORY/setup-token"
    export CPTR_STARTUP_TOKEN="$setupToken"

    exec ${pkgs.uv}/bin/uvx \
      --python ${pkgs.python3}/bin/python \
      --from 'cptr[all]==${computerVersion}' \
      python -m uvicorn cptr.app:application \
      --host ${lib.escapeShellArg server.lan.serverIp} \
      --port ${toString computerPort}
  '';
in
{
  virtualisation.vmVariant.dotfiles.scopes.serverApps.openWebui.enable = lib.mkForce false;

  users.users = {
    open-webui = {
      isSystemUser = true;
      group = appData.group.name;
    };

    ${hostAdmin.user} = {
      isSystemUser = true;
      group = hostAdmin.user;
      shell = pkgs.bashInteractive;
      hashedPassword = "!";
    };
  };

  users.groups.${hostAdmin.user} = { };

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
      RuntimeDirectory = hostAdmin.runtimeDirectory;
      RuntimeDirectoryMode = "0755";
      LoadCredential = "host-admin-key:${hostAdmin.privateKeySecret}";
    };
    script = ''
      set -euo pipefail
      tmp="$(${pkgs.coreutils}/bin/mktemp)"
      trap '${pkgs.coreutils}/bin/rm -f "$tmp"' EXIT

      ${pkgs.openssh}/bin/ssh-keygen -y -f "$CREDENTIALS_DIRECTORY/host-admin-key" |
        ${pkgs.gawk}/bin/awk '{ print "restrict,from=\"127.0.0.1,::1\" " $1 " " $2 " open-webui-host-admin@nixos-server" }' > "$tmp"
      ${pkgs.coreutils}/bin/install -m 0444 "$tmp" "$RUNTIME_DIRECTORY/${hostAdmin.user}"
    '';
  };

  services.openssh.authorizedKeysFiles = [ "/run/${hostAdmin.runtimeDirectory}/%u" ];

  services.open-webui = {
    enable = true;
    stateDir = openWebuiStateDir;
    host = server.lan.serverIp;
    port = openWebuiPort;
    environmentFile = openWebuiSecret;
    environment = {
      WEBUI_URL = "http://${server.lan.serverIp}:${toString openWebuiPort}";
      ENABLE_WEB_SEARCH = "True";
      WEB_SEARCH_ENGINE = "searxng";
      WEB_SEARCH_RESULT_COUNT = "5";
      WEB_SEARCH_CONCURRENT_REQUESTS = "5";
      SEARXNG_QUERY_URL = "http://127.0.0.1:${toString searxPort}/search?q=<query>";
      ENABLE_USER_WEBHOOKS = "True";

      # Timers provide a durable, upstream-owned restart-recovery primitive for
      # agent workflows. A relaxed poll interval keeps idle load low on the Pi.
      ENABLE_SUBAGENTS = "True";
      ENABLE_TOOL_PERMISSIONS = "True";
      TIMER_POLL_INTERVAL = "15";

      # Keep disposable model caches out of the backed-up application state.
      HF_HOME = "/var/cache/open-webui/huggingface";
    };
    openFirewall = false;
  };

  systemd.services.open-webui = {
    unitConfig.AssertPathExists = [ openWebuiSecret ];
    serviceConfig = {
      # The native module hardcodes StateDirectory=open-webui even when stateDir
      # points elsewhere. Keep a stable uid for our backed-up custom state path.
      DynamicUser = lib.mkForce false;
      User = "open-webui";
      Group = appData.group.name;
      StateDirectory = lib.mkForce "";
      CacheDirectory = "open-webui";
      CacheDirectoryMode = "0700";
      UnsetEnvironment = [ "SENTENCE_TRANSFORMERS_HOME" ];
      ProtectSystem = "strict";
      ReadWritePaths = [ openWebuiStateDir ];
    };
  };

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

  # Computer has no native NixOS service. Pin it through uvx, keep durable state
  # under appData, and use only upstream application state for one-time setup.
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
      gh
      jq
      nix
      openssh
      systemd
      hostCommand
    ];
    environment = {
      CPTR_DATA_DIR = computerStateDir;
      CPTR_LOG_LEVEL = "WARNING";
      # Gateway-created .cptr exports bypass Computer's auto-ignore helper.
      # Workspace repos ignore them privately via .git/info/exclude, so never edit tracked .gitignore files.
      CPTR_AUTO_GITIGNORE_DOT_CPTR = "false";
      ENABLE_CHAT_RECONCILE_ON_STARTUP = "true";
      LD_LIBRARY_PATH = lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ];
      SEARXNG_BASE_URL = "http://127.0.0.1:${toString searxPort}";
      UV_CACHE_DIR = "/var/cache/open-webui-computer/uv";
      UV_PYTHON_DOWNLOADS = "never";
    };
    unitConfig.AssertPathExists = [
      computerGithubSecret
      hostAdmin.privateKeySecret
    ];
    serviceConfig = {
      Type = "simple";
      EnvironmentFile = computerGithubSecret;
      User = primary.name;
      Group = "users";
      WorkingDirectory = config.users.users.${primary.name}.home;
      CacheDirectory = "open-webui-computer";
      CacheDirectoryMode = "0700";
      RuntimeDirectory = "open-webui-computer";
      RuntimeDirectoryMode = "0700";
      ExecStart = computerStart;
      LoadCredential = "host-admin-key:${hostAdmin.privateKeySecret}";
      Restart = "on-failure";
      RestartSec = "5s";
      UMask = "0077";
    };
  };

  systemd.tmpfiles.rules = [
    "d ${openWebuiStateDir} 0770 open-webui ${appData.group.name} - -"
    "Z ${openWebuiStateDir} - open-webui ${appData.group.name} - -"
    "d ${computerRoot} 0700 ${primary.name} users - -"
    "d ${computerStateDir} 0700 ${primary.name} users - -"
  ];

  networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts = [
    openWebuiPort
    computerPort
  ];
}
