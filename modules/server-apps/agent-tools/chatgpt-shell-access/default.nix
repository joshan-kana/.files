{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.dotfiles) server;
  inherit (config.dotfiles.users) primary;
  gateway = "chatgpt-shell-access";
  stateRoot = "${server.storage.appData.root}/chatgpt-shell-gateway";
  operatorStateRoot = "${server.storage.appData.root}/chatgpt-shell-operator-secure";
  approvalRoot = "/run/chatgpt-shell-approvals";
  workspaces = config.systemd.services.agent-workspaces;
  tunnelSecret = "${server.secretsDir}/chatgpt-shell-tunnel.env";
  macSshKeySecret = "${server.secretsDir}/chatgpt-shell-mac";
  parallelsSshKeySecret = "${server.secretsDir}/chatgpt-shell-nixos-arm-parallels";
  parallelsSudoSshKeySecret = "${server.secretsDir}/nixos-arm-parallels-sudo";
  githubSecret = "${server.secretsDir}/github-self-hosted-agents.env";
  knownHostsFile = "${config.users.users.${primary.name}.home}/.ssh/known_hosts";
  remoteAuthAgentSocket = "/run/${gateway}/remote-sudo-agent.sock";

  macHost = "mac.home";
  parallelsHost = "nixos-arm-parallels.home";

  defaultPolicy = {
    commands = "automatic";
    elevation = "automatic";
  };
  remoteTargets = {
    mac = {
      sshTarget = "${primary.name}@${macHost}";
      credential = macSshKeySecret;
      shell = "/bin/zsh";
      policy = {
        commands = "ask";
        elevation = "deny";
      };
    };
    nixos-arm-parallels = {
      sshTarget = "${primary.name}@${parallelsHost}";
      credential = parallelsSshKeySecret;
      shell = "/run/current-system/sw/bin/bash";
      policy = defaultPolicy;
    };
  };
  remoteTargetConfig = lib.mapAttrs (name: target: {
    ssh_target = target.sshTarget;
    credential = "chatgpt-shell-${name}";
    inherit (target) shell;
  }) remoteTargets;
  policyDefaults = pkgs.writeText "chatgpt-shell-policies.json" (
    builtins.toJSON (
      lib.mapAttrs (_: target: target.policy) remoteTargets
      // {
        "${config.networking.hostName}" = defaultPolicy;
      }
    )
  );
  approvalCommand = pkgs.writeShellScriptBin "chatgpt-shell-approval" ''
    export CHATGPT_SHELL_APPROVAL_DIR=${approvalRoot}
    export CHATGPT_SHELL_STATE_DIR=${lib.escapeShellArg stateRoot}
    export CHATGPT_SHELL_OPERATOR_STATE_DIR=${lib.escapeShellArg operatorStateRoot}
    export CHATGPT_SHELL_POLICIES_FILE=${policyDefaults}
    exec ${pkgs.python3}/bin/python3 ${./.}/authorization.py "$@"
  '';
  shellPackages = workspaces.path;

in
{
  users.groups.${gateway} = { };
  users.users.${gateway} = {
    isSystemUser = true;
    group = gateway;
    home = stateRoot;
  };

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id === "org.freedesktop.systemd1.manage-units" && subject.user === "${gateway}")
        return polkit.Result.YES;
    });
  '';

  environment.systemPackages = [
    approvalCommand
  ];

  services.logrotate.settings.chatgpt-shell-access = {
    files = [ "${stateRoot}/events.jsonl" ];
    frequency = "weekly";
    rotate = 8;
    compress = true;
    missingok = true;
    notifempty = true;
    su = "${gateway} ${gateway}";
  };

  systemd.tmpfiles.rules = [
    "a+ ${server.storage.appData.root} - - - - u:${gateway}:--x"
    "d ${stateRoot} 0700 ${gateway} ${gateway} - -"
    "f ${stateRoot}/events.jsonl 0600 ${gateway} ${gateway} - -"
    "d ${operatorStateRoot} 2750 root ${gateway} - -"
    "d ${approvalRoot} 0750 root ${gateway} - -"
    "d ${approvalRoot}/pending 0700 ${gateway} ${gateway} - -"
    "d ${approvalRoot}/decisions 2750 root ${gateway} - -"
    "e ${approvalRoot}/decisions - - - 1d -"
  ];
  systemd.services.chatgpt-shell-access = {
    description = "ChatGPT shell access through OpenAI Secure MCP Tunnel";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "agent-workspaces.service"
    ];
    wants = [
      "network-online.target"
      "agent-workspaces.service"
    ];

    unitConfig.RequiresMountsFor = [ stateRoot ];
    unitConfig.AssertPathExists = [
      tunnelSecret
      parallelsSudoSshKeySecret
      githubSecret
      knownHostsFile
    ]
    ++ lib.mapAttrsToList (_: target: target.credential) remoteTargets;

    path = shellPackages;

    environment = {
      HEALTH_LISTEN_ADDR = "127.0.0.1:18792";
      MCP_COMMAND = "${pkgs.coreutils}/bin/env -u CONTROL_PLANE_API_KEY -u CONTROL_PLANE_TUNNEL_ID ${pkgs.chatgpt-shell-mcp-python}/bin/python3 ${./.}/chatgpt-shell-access.py";
      CHATGPT_SHELL_COMMAND_PATH = lib.makeBinPath shellPackages;
      CHATGPT_SHELL_LOCAL_HOST = config.networking.hostName;
      CHATGPT_SHELL_WORKER = workspaces.serviceConfig.User;
      CHATGPT_SHELL_WORKER_ENV = builtins.toJSON workspaces.environment;
      CHATGPT_SHELL_RUN0 = "${pkgs.systemd}/bin/run0";
      CHATGPT_SHELL_BASH = "${pkgs.bash}/bin/bash";
      CHATGPT_SHELL_HC = "${pkgs.herdr-core}/bin/hc";
      CHATGPT_SHELL_APPROVAL_DIR = approvalRoot;
      CHATGPT_SHELL_STATE_DIR = stateRoot;
      CHATGPT_SHELL_OPERATOR_STATE_DIR = operatorStateRoot;
      CHATGPT_SHELL_POLICIES_FILE = toString policyDefaults;
      CHATGPT_SHELL_REMOTE_AUTH_AGENT = remoteAuthAgentSocket;
      CHATGPT_SHELL_REMOTE_TARGETS = builtins.toJSON remoteTargetConfig;
    };

    serviceConfig = {
      Type = "simple";
      User = gateway;
      RuntimeDirectory = gateway;
      RuntimeDirectoryMode = "0700";
      EnvironmentFile = [
        tunnelSecret
        githubSecret
      ];
      LoadCredential =
        lib.mapAttrsToList (name: target: "chatgpt-shell-${name}:${target.credential}") remoteTargets
        ++ [
          "nixos-arm-parallels-sudo:${parallelsSudoSshKeySecret}"
          "chatgpt-shell-known-hosts:${knownHostsFile}"
        ];
      ExecStart = pkgs.writeShellScript "chatgpt-shell-access-start" ''
        set -euo pipefail
        rm -f "$CHATGPT_SHELL_REMOTE_AUTH_AGENT"
        ${pkgs.openssh}/bin/ssh-agent -D -a "$CHATGPT_SHELL_REMOTE_AUTH_AGENT" >/dev/null &
        for _ in $(seq 1 100); do
          [ -S "$CHATGPT_SHELL_REMOTE_AUTH_AGENT" ] && break
          sleep 0.05
        done
        [ -S "$CHATGPT_SHELL_REMOTE_AUTH_AGENT" ]
        cat "$CREDENTIALS_DIRECTORY/nixos-arm-parallels-sudo" | \
          ${pkgs.bash}/bin/bash -c \
            'SSH_AUTH_SOCK="$1" exec ${pkgs.openssh}/bin/ssh-add -' _ "$CHATGPT_SHELL_REMOTE_AUTH_AGENT"
        exec ${pkgs.openai-tunnel-client}/bin/tunnel-client run --log.level=info --log.format=struct-text
      '';
      Restart = "always";
      RestartSec = "2s";
      UMask = "0077";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [
        stateRoot
        "${approvalRoot}/pending"
      ];
    };
  };
}
