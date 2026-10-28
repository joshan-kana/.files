{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.dotfiles) server;
  inherit (config.dotfiles.users) primary;
  gatewayPort = 18789;
  internalTlsDir = "${server.secretsDir}/internal-tls";
  openclawTlsCert = "${internalTlsDir}/nixos-server.home.crt";
  openclawTlsKey = "${internalTlsDir}/nixos-server.home.key";
  openclawUser = "openclaw";
  openclawStateDir = "${server.storage.appData.root}/openclaw";
  openclawConfigFile = "${openclawStateDir}/openclaw.json";

  openclawPackage = pkgs.openclaw-gateway;

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
    ];
  };

  environment.etc."openclaw/openclaw.json".mode = lib.mkForce "direct-symlink";

  systemd.services.openclaw-gateway = {
    unitConfig = {
      AssertPathExists = openclawSecrets ++ [
        openclawConfigFile
        openclawTlsCert
        openclawTlsKey
      ];
      RequiresMountsFor = [ mappedHome ];
    };
    serviceConfig = {
      BindPaths = [ "${mappedHome}:${primaryHome}" ];
      LoadCredential = [
        "nixos-server.home.crt:${openclawTlsCert}"
        "nixos-server.home.key:${openclawTlsKey}"
      ];
      UMask = "0077";
    };
  };

  networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts = [ gatewayPort ];

  # The worker was already root-equivalent; retain that authority through
  # run0 rather than a passwordless sudoers exception.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" && subject.user == "${openclawUser}") {
        return polkit.Result.YES;
      }
    });
  '';

  # bindfs maps OpenClaw writes back to the primary user to preserve ownership.
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

    appendHttpConfig = ''
      resolver 127.0.0.1 valid=30s ipv6=off;

      upstream openclaw_ollama {
        zone openclaw_ollama 64k;
        server mac.home:11434 resolve;
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
