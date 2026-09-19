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
  hermesUser = "hermes";
  hermesState = "${server.storage.appData.root}/hermes";
  hermesHome = "${hermesState}/.hermes";
  hermesSecret = "${server.secretsDir}/hermes.env";
  githubSecret = "${server.secretsDir}/github-self-hosted-agents.env";
  primaryHome = "${primary.homeRoot}/${primary.name}";
  primaryGroup = config.users.users.${primary.name}.group;
  mappedHome = "/run/hermes-home";

  bindfsArgs = [
    "-f"
    "--map=${primary.name}/${hermesUser}"
    "--create-for-user=${primary.name}"
    "--create-for-group=${primaryGroup}"
    primaryHome
    mappedHome
  ];

  hermesPackage = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.hermes-agent;

  hermesHomeUnmount = pkgs.writeShellScript "hermes-home-unmount" ''
    if ${pkgs.util-linux}/bin/mountpoint -q ${mappedHome}; then
      exec ${pkgs.fuse3}/bin/fusermount3 -u ${mappedHome}
    fi
  '';

  hermesHomeReady = pkgs.writeShellScript "hermes-home-ready" ''
    attempts=0
    while [ "$attempts" -lt 100 ]; do
      if ${pkgs.util-linux}/bin/mountpoint -q ${mappedHome}; then
        exit 0
      fi
      attempts=$((attempts + 1))
      ${pkgs.coreutils}/bin/sleep 0.1
    done

    echo "Timed out waiting for ${mappedHome} to become a mount point" >&2
    exit 1
  '';

  hermesGh = pkgs.writeShellApplication {
    name = "gh";
    text = ''
      token="$(${pkgs.gnused}/bin/sed -n 's/^GH_TOKEN=//p' "$HERMES_HOME/.env" | ${pkgs.coreutils}/bin/tail -n 1)"
      if [ -z "$token" ]; then
        echo "GH_TOKEN is not provisioned in $HERMES_HOME/.env" >&2
        exit 1
      fi
      export GH_TOKEN="$token"
      exec ${pkgs.gh}/bin/gh "$@"
    '';
  };

  hermesExtraPackages =
    with pkgs;
    [
      curl
      docker
      jq
      nh
      nix
      openssh
      rsync
      systemd
    ]
    ++ [ hermesGh ];

  hermesSudo = pkgs.writeShellScriptBin "sudo" ''
    exec /run/wrappers/bin/sudo "$@"
  '';

  hermesServiceCli = pkgs.writeShellScriptBin "hermes-service-cli" ''
    export HOME=${hermesState}
    export HERMES_HOME=${hermesHome}
    export PATH=${
      lib.makeBinPath (
        [
          hermesPackage
          pkgs.bash
          pkgs.coreutils
          pkgs.git
          hermesSudo
        ]
        ++ hermesExtraPackages
      )
    }
    exec ${hermesPackage}/bin/hermes "$@"
  '';

  hermesLauncher = pkgs.writeShellScriptBin "hermes-launcher" ''
    set -euo pipefail

    pid="$(${pkgs.systemd}/bin/systemctl show --property=MainPID --value hermes-agent.service)"
    if [ -z "$pid" ] || [ "$pid" = "0" ]; then
      echo "hermes-agent.service is not running" >&2
      exit 1
    fi

    nsenter=${pkgs.util-linux}/bin/nsenter
    sudo=/run/wrappers/bin/sudo
    cli=${hermesServiceCli}/bin/hermes-service-cli
    exec "$nsenter" --target "$pid" --mount --wdns="$PWD" -- "$sudo" -n -H -u ${hermesUser} -- "$cli" "$@"
  '';

  hermesCli = pkgs.writeShellScriptBin "hermes" ''
    exec /run/wrappers/bin/sudo -n ${hermesLauncher}/bin/hermes-launcher "$@"
  '';
in
{
  services.hermes-agent = {
    enable = true;
    package = hermesPackage;
    addToSystemPackages = false;
    createUser = true;
    user = hermesUser;
    group = server.storage.appData.group.name;
    stateDir = hermesState;

    extraPackages = hermesExtraPackages ++ [ hermesSudo ];

    environment = {
      MATRIX_HOMESERVER = "https://matrix.org";
      MATRIX_USER_ID = "@joshans-bot:matrix.org";
      MATRIX_SESSION_SCOPE = "room";
      MATRIX_E2EE_MODE = "off";

      GIT_CONFIG_COUNT = "2";
      GIT_CONFIG_KEY_0 = "url.https://github.com/.insteadOf";
      GIT_CONFIG_VALUE_0 = "git@github.com:";
      GIT_CONFIG_KEY_1 = "credential.https://github.com.helper";
      GIT_CONFIG_VALUE_1 = "!${hermesGh}/bin/gh auth git-credential";
    };
    environmentFiles = [
      hermesSecret
      githubSecret
    ];

    settings = {
      model = {
        provider = "openai-codex";
        default = "gpt-5.6-luna";
      };
      toolsets = [ "all" ];
    };
  };

  environment.systemPackages = [ hermesCli ];

  security.sudo.extraRules = [
    {
      users = [ primary.name ];
      runAs = "root";
      commands = [
        {
          command = "${hermesLauncher}/bin/hermes-launcher";
          options = [ "NOPASSWD" ];
        }
      ];
    }
    {
      users = [ hermesUser ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  systemd.tmpfiles.rules = [
    "d ${mappedHome} 0700 root root - -"
  ];

  systemd.services.hermes-home = {
    description = "Hermes mapped primary home";
    before = [ "hermes-agent.service" ];

    unitConfig.AssertPathExists = primaryHome;

    serviceConfig = {
      Type = "simple";
      ExecStartPre = [ hermesHomeUnmount ];
      ExecStart = "${pkgs.bindfs}/bin/bindfs ${lib.escapeShellArgs bindfsArgs}";
      ExecStartPost = [ hermesHomeReady ];
      ExecStop = [ hermesHomeUnmount ];
      Restart = "on-failure";
      RestartSec = "1s";
    };
  };

  systemd.services.hermes-agent = {
    requires = [ "hermes-home.service" ];
    after = [ "hermes-home.service" ];

    unitConfig.AssertPathExists = [
      hermesSecret
      githubSecret
    ];

    serviceConfig = {
      BindPaths = [ "${mappedHome}:${primaryHome}" ];
      NoNewPrivileges = lib.mkForce false;
      ProtectSystem = lib.mkForce false;
    };
  };
}
