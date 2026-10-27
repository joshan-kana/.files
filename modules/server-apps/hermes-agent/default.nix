{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.dotfiles) server;
  inherit (config.dotfiles.users) primary;
  hermesUser = "hermes";
  hermesSecret = "${server.secretsDir}/hermes.env";
  githubSecret = "${server.secretsDir}/github-self-hosted-agents.env";
  primaryHome = "${primary.homeRoot}/${primary.name}";
  mappedHome = "/run/hermes-home";

  hermesPackage = pkgs.hermes-agent;

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

  hermesServiceCli = pkgs.writeShellScriptBin "hermes-service-cli" ''
    export HOME=${lib.escapeShellArg config.systemd.services.hermes-agent.environment.HOME}
    export HERMES_HOME=${lib.escapeShellArg config.systemd.services.hermes-agent.environment.HERMES_HOME}
    export HERMES_MANAGED=${lib.escapeShellArg config.systemd.services.hermes-agent.environment.HERMES_MANAGED}
    export PATH=${lib.escapeShellArg config.systemd.services.hermes-agent.environment.PATH}
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
    runuser=${pkgs.util-linux}/bin/runuser
    cli=${hermesServiceCli}/bin/hermes-service-cli
    exec "$nsenter" --target "$pid" --mount --wdns="$PWD" -- "$runuser" -u ${hermesUser} -- "$cli" "$@"
  '';

  hermesCli = pkgs.writeShellScriptBin "hermes" ''
    exec ${pkgs.systemd}/bin/run0 ${hermesLauncher}/bin/hermes-launcher "$@"
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
    stateDir = "${server.storage.appData.root}/hermes";

    extraPackages = hermesExtraPackages;

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
        default = "gpt-6-luna";
      };
      toolsets = [ "all" ];
    };
  };

  environment.systemPackages = [ hermesCli ];

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" && subject.user == "${hermesUser}") {
        return polkit.Result.YES;
      }
    });
  '';

  fileSystems.${mappedHome} = {
    device = primaryHome;
    fsType = "fuse.bindfs";
    options = [
      "map=${primary.name}/${hermesUser}"
      "create-for-user=${primary.name}"
      "create-for-group=${config.users.users.${primary.name}.group}"
    ];
  };

  systemd.services.hermes-agent = {
    unitConfig = {
      AssertPathExists = [
        hermesSecret
        githubSecret
      ];
      RequiresMountsFor = [ mappedHome ];
    };

    serviceConfig = {
      BindPaths = [ "${mappedHome}:${primaryHome}" ];
      NoNewPrivileges = lib.mkForce false;
      ProtectSystem = lib.mkForce false;
    };
  };
}
