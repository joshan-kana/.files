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

  openclawPackage = inputs.nix-openclaw.packages.${pkgs.stdenv.hostPlatform.system}.openclaw-gateway;

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

in
{
  services.openclaw-gateway = {
    enable = true;
    package = openclawPackage;
    port = gatewayPort;
    user = openclawUser;
    group = appDataGroup;
    stateDir = openclawStateDir;
    configFile = openclawConfigFile;

    environment = {
      OPENCLAW_NIX_MODE = "0";
      GIT_CONFIG_COUNT = "2";
      GIT_CONFIG_KEY_0 = "url.https://github.com/.insteadOf";
      GIT_CONFIG_VALUE_0 = "git@github.com:";
      GIT_CONFIG_KEY_1 = "credential.https://github.com.helper";
      GIT_CONFIG_VALUE_1 = "!${pkgs.gh}/bin/gh auth git-credential";

      # Config writes replace symlinks, so use the app-owned file directly.
      OPENCLAW_CONFIG_PATH = openclawConfigFile;
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

  environment.etc."openclaw/openclaw.json".mode = lib.mkForce "direct-symlink";

  systemd.services.openclaw-gateway = {
    unitConfig = {
      AssertPathExists = openclawSecrets ++ [ openclawConfigFile ];
      RequiresMountsFor = [ mappedHome ];
    };
    serviceConfig = {
      BindPaths = [ "${mappedHome}:${primaryHome}" ];
      UMask = "0077";
    };
  };

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
      if [ -e ${lib.escapeShellArg openclawConfigFile} ] && [ "$(${pkgs.coreutils}/bin/stat -c %u ${lib.escapeShellArg openclawConfigFile})" = "$(${pkgs.coreutils}/bin/id -u ${primary.name})" ]; then
        ${pkgs.coreutils}/bin/chown -R ${openclawUser}:${appDataGroup} ${lib.escapeShellArg openclawStateDir}
      fi
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
      resolver 127.0.0.1 valid=30s ipv6=off;

      upstream openclaw_ollama {
        zone openclaw_ollama 64k;
        server mac.home:11434 resolve;
        server joshans-macbook-pro.tailba46a0.ts.net:11434 resolve backup;
      }

      server {
        listen 127.0.0.1:11434;
        server_name ollama-proxy;

        location / {
          proxy_pass http://openclaw_ollama;
          proxy_connect_timeout 2s;
          proxy_read_timeout 300s;
          proxy_send_timeout 300s;
          proxy_http_version 1.1;
          proxy_set_header Connection "";
          proxy_set_header Host $host;
        }
      }
    '';
  };

}
