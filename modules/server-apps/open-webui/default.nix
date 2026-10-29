{
  config,
  lib,
  ...
}:

let
  inherit (config.dotfiles) server;
  inherit (server.storage) appData;

  openWebuiPort = 8081;
  openWebuiStateDir = "${appData.root}/open-webui";
  openWebuiSecret = "${server.secretsDir}/open-webui.env";
  searxPort = 8888;
in
{
  virtualisation.vmVariant.dotfiles.scopes.serverApps.openWebui.enable = lib.mkForce false;

  users.users.open-webui = {
    isSystemUser = true;
    group = appData.group.name;
  };

  services.open-webui = {
    enable = true;
    stateDir = openWebuiStateDir;
    host = server.lan.serverIp;
    port = openWebuiPort;
    environmentFile = openWebuiSecret;
    environment = {
      WEBUI_URL = "http://${server.lan.serverIp}:${toString openWebuiPort}";
      ENABLE_USER_WEBHOOKS = "True";
      ENABLE_SUBAGENTS = "True";
      ENABLE_TOOL_PERMISSIONS = "True";
      HF_HOME = "/var/cache/open-webui/huggingface";
    };
    openFirewall = false;
  };

  systemd.services.open-webui = {
    unitConfig.AssertPathExists = [ openWebuiSecret ];
    serviceConfig = {
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

  systemd.tmpfiles.rules = [
    "d ${openWebuiStateDir} 0770 open-webui ${appData.group.name} - -"
    "Z ${openWebuiStateDir} - open-webui ${appData.group.name} - -"
  ];

  networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts = [ openWebuiPort ];

  computer =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (config.dotfiles) server;
      inherit (config.dotfiles.users) primary;
      inherit (server.storage) appData;

      computerUser = "open-webui-computer";
      computerVersion = pkgs.open-webui-computer.version;
      computerPort = 8000;
      computerRoot = "${appData.root}/open-webui-computer";
      computerStateDir = "${computerRoot}/state";
      computerGithubSecret = "${server.secretsDir}/github-self-hosted-agents.env";
      primaryHome = "${primary.homeRoot}/${primary.name}";
      computerMappedHome = "/run/open-webui-computer-home";
      searxEnabled = config.dotfiles.resolvedScopes.serverApps.openWebui.searx.enable;

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
      users.users.${computerUser} = {
        isSystemUser = true;
        group = appData.group.name;
        home = computerRoot;
      };

      security.polkit.extraConfig = ''
        polkit.addRule(function(action, subject) {
          if (action.id == "org.freedesktop.systemd1.manage-units" && subject.user == "${computerUser}") {
            return polkit.Result.YES;
          }
        });
      '';

      fileSystems.${computerMappedHome} = {
        device = primaryHome;
        fsType = "fuse.bindfs";
        options = [
          "map=${primary.name}/${computerUser}"
          "create-for-user=${primary.name}"
          "create-for-group=${config.users.users.${primary.name}.group}"
        ];
      };

      systemd.services.open-webui-computer = {
        description = "Open WebUI Computer server worker";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ] ++ lib.optional searxEnabled "searx.service";
        wants = [ "network-online.target" ] ++ lib.optional searxEnabled "searx.service";
        path = with pkgs; [
          bash
          chromium
          codex
          coreutils
          curl
          git
          gh
          jq
          nix
          systemd
        ];
        environment = {
          HOME = computerRoot;
          CPTR_DATA_DIR = computerStateDir;
          # Keep generated .cptr exports out of tracked workspace .gitignore files.
          CPTR_AUTO_GITIGNORE_DOT_CPTR = "false";
          CPTR_PORT = toString computerPort;
          LD_LIBRARY_PATH = lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ];
          UV_CACHE_DIR = "/var/cache/open-webui-computer/uv";
          UV_PYTHON_DOWNLOADS = "never";
        }
        // lib.optionalAttrs searxEnabled {
          SEARXNG_BASE_URL = "http://127.0.0.1:${toString searxPort}";
        };
        unitConfig = {
          AssertPathExists = [ computerGithubSecret ];
          RequiresMountsFor = [ computerMappedHome ];
        };
        serviceConfig = {
          Type = "simple";
          EnvironmentFile = computerGithubSecret;
          User = computerUser;
          Group = appData.group.name;
          WorkingDirectory = primaryHome;
          BindPaths = [ "${computerMappedHome}:${primaryHome}" ];
          CacheDirectory = "open-webui-computer";
          CacheDirectoryMode = "0700";
          RuntimeDirectory = "open-webui-computer";
          RuntimeDirectoryMode = "0700";
          ExecStart = computerStart;
          Restart = "on-failure";
          RestartSec = "5s";
          UMask = "0077";
        };
      };

      systemd.tmpfiles.rules = [
        "d ${computerRoot} 0700 ${computerUser} ${appData.group.name} - -"
        "d ${computerStateDir} 0700 ${computerUser} ${appData.group.name} - -"
        "Z ${computerRoot} - ${computerUser} ${appData.group.name} - -"
      ];

      networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts = [ computerPort ];
    };

  searx =
    { config, ... }:
    let
      inherit (config.dotfiles) server;

      searxSecret = "${server.secretsDir}/searxng.env";
    in
    {
      services.open-webui.environment = {
        ENABLE_WEB_SEARCH = "True";
        WEB_SEARCH_ENGINE = "searxng";
        SEARXNG_QUERY_URL = "http://127.0.0.1:${toString searxPort}/search?q=<query>";
      };

      services.searx = {
        environmentFile = searxSecret;
        settings = {
          use_default_settings.engines.keep_only = [
            "bing"
            "github"
            "stackoverflow"
          ];
          engines = [
            {
              name = "bing";
              disabled = false;
            }
          ];
          server = {
            port = searxPort;
            bind_address = "127.0.0.1";
            secret_key = "$SEARX_SECRET_KEY";
            image_proxy = true;
          };
          search.formats = [
            "html"
            "json"
          ];
        };
      };

      systemd.services.searx-init.unitConfig.AssertPathExists = [ searxSecret ];
    };
}
