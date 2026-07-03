{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  primaryUser = config.dotfiles.users.primary.name;
  serverCfg = config.dotfiles.server;
  inherit (serverCfg) appDataRoot secretsDir;

  system = pkgs.stdenv.hostPlatform.system;
  openclawPackage = inputs.llm-agents.packages.${system}.openclaw;

  stateDir = "${appDataRoot}/openclaw";
  authDir = "${appDataRoot}/openclaw-auth";
  configPath = "${stateDir}/openclaw.json";
  logDir = "${stateDir}/logs";

  openclawHostAdmin = {
    user = "openclaw-admin";
    privateKeyPath = "${secretsDir}/openclaw-host-admin-id_ed25519";
  };
in
{
  assertions = [
    {
      assertion = inputs.llm-agents.packages.${system} ? openclaw;
      message = "numtide/llm-agents.nix does not provide openclaw for ${system}";
    }
  ];

  environment.systemPackages = [ openclawPackage ];

  virtualisation.oci-containers.containers.openclaw.autoStart = lib.mkForce false;
  systemd.services.docker-openclaw.enable = lib.mkForce false;

  systemd.tmpfiles.rules = [
    "d ${stateDir} 0750 ${primaryUser} appdata-editors - -"
    "d ${authDir} 0750 ${primaryUser} appdata-editors - -"
    "d ${logDir} 0750 ${primaryUser} appdata-editors - -"
    "z ${openclawHostAdmin.privateKeyPath} 0400 ${primaryUser} root - -"
    "z ${openclawHostAdmin.privateKeyPath}.pub 0644 root root - -"
  ];

  systemd.services.configure-native-openclaw-gateway = {
    description = "Write native OpenClaw gateway config";
    before = [ "openclaw-gateway.service" ];
    path = with pkgs; [
      coreutils
      jq
    ];
    serviceConfig.Type = "oneshot";
    script = ''
      install -d -m 0750 -o ${primaryUser} -g appdata-editors ${stateDir}
      install -d -m 0750 -o ${primaryUser} -g appdata-editors ${authDir}
      install -d -m 0750 -o ${primaryUser} -g appdata-editors ${logDir}

      if [ ! -f ${configPath} ]; then
        install -m 0600 -o ${primaryUser} -g appdata-editors /dev/null ${configPath}
        printf '{}\n' > ${configPath}
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
        | .gateway.mode = "local"
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
      ' ${configPath} > "$tmp"

      install -m 0600 -o ${primaryUser} -g appdata-editors "$tmp" ${configPath}
      rm -f "$tmp"
    '';
  };

  systemd.services.openclaw-gateway = {
    description = "Native OpenClaw gateway";
    wantedBy = [ "multi-user.target" ];
    after = [
      "configure-native-openclaw-gateway.service"
      "network-online.target"
      "nginx.service"
      "openclaw-ollama-proxy.service"
    ];
    requires = [ "configure-native-openclaw-gateway.service" ];
    wants = [
      "network-online.target"
      "nginx.service"
      "openclaw-ollama-proxy.service"
    ];
    conflicts = [ "docker-openclaw.service" ];
    restartTriggers = [ openclawPackage ];

    environment = {
      HOME = stateDir;
      XDG_CONFIG_HOME = authDir;
      OPENCLAW_STATE_DIR = stateDir;
      OPENCLAW_CONFIG_PATH = configPath;
      CLAWDBOT_STATE_DIR = stateDir;
      CLAWDBOT_CONFIG_PATH = configPath;
      OPENCLAW_DISABLE_BONJOUR = "1";
      OLLAMA_API_KEY = "ollama-local";
      OPENCLAW_HOST_ADMIN_SSH = "${pkgs.openssh}/bin/ssh -i ${openclawHostAdmin.privateKeyPath} -o StrictHostKeyChecking=accept-new ${openclawHostAdmin.user}@127.0.0.1";
    };

    path = with pkgs; [
      bash
      coreutils
      curl
      git
      jq
      nix
      openssh
    ];

    serviceConfig = {
      User = primaryUser;
      Group = "users";
      SupplementaryGroups = [ "appdata-editors" ];
      WorkingDirectory = stateDir;
      EnvironmentFile = [ "-${secretsDir}/openclaw.env" ];
      ExecStart = "${lib.getExe openclawPackage} gateway --port 18789";
      Restart = "always";
      RestartSec = 5;
      StandardOutput = "append:${logDir}/gateway.log";
      StandardError = "append:${logDir}/gateway.log";
    };
  };
}
