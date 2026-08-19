{
  config,
  pkgs,
  ...
}:

let
  primaryUser = config.dotfiles.users.primary.name;
  serverCfg = config.dotfiles.server;
  inherit (serverCfg) secretsDir;
  appDataRoot = serverCfg.storage.appData.root;
  appDataGroup = serverCfg.storage.appData.group.name;

  computerVersion = "0.9.21";
  computerPort = 8000;
  computerRoot = "${appDataRoot}/open-webui-computer";
  computerStateDir = "${computerRoot}/state";
  computerToolDir = "${computerRoot}/uv-tools";
  computerBinDir = "${computerRoot}/bin";
  computerCacheDir = "${computerRoot}/uv-cache";
  computerVersionFile = "${computerRoot}/.installed-version";
  computerStartupLog = "${computerRoot}/startup.log";

  hostAdmin = {
    user = "open-webui-admin";
    privateKeyPath = "${secretsDir}/open-webui-host-admin-id_ed25519";
    publicKeyPath = "${secretsDir}/open-webui-host-admin-id_ed25519.pub";
  };

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

  installComputer = pkgs.writeShellScript "install-open-webui-computer" ''
    set -euo pipefail

    export UV_TOOL_DIR=${computerToolDir}
    export UV_TOOL_BIN_DIR=${computerBinDir}
    export UV_CACHE_DIR=${computerCacheDir}

    installedVersion="$(cat ${computerVersionFile} 2>/dev/null || true)"
    if [ "$installedVersion" != "${computerVersion}" ] || [ ! -x ${computerBinDir}/cptr ]; then
      ${pkgs.uv}/bin/uv tool install \
        --force \
        --python ${pkgs.python312}/bin/python \
        'cptr[all]==${computerVersion}'
      printf '%s\n' '${computerVersion}' > ${computerVersionFile}
    fi
  '';
in
{
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

  system.activationScripts.openWebuiHostAdminAuthorizedKeys = {
    deps = [ "users" ];
    text = ''
      keyFile=${hostAdmin.publicKeyPath}
      home=/home/${hostAdmin.user}

      if [ -f "$keyFile" ]; then
        ${pkgs.coreutils}/bin/install -d -m 0700 -o ${hostAdmin.user} -g users "$home/.ssh"
        ${pkgs.gawk}/bin/awk '{ print "from=\"127.0.0.1,::1\" " $1 " " $2 " open-webui-host-admin@nixos-server" }' "$keyFile" > "$home/.ssh/authorized_keys"
        ${pkgs.coreutils}/bin/chown ${hostAdmin.user}:users "$home/.ssh/authorized_keys"
        ${pkgs.coreutils}/bin/chmod 0600 "$home/.ssh/authorized_keys"
      fi
    '';
  };

  systemd.tmpfiles.rules = [
    "d ${computerRoot} 0700 ${primaryUser} users - -"
    "d ${computerStateDir} 0700 ${primaryUser} users - -"
    "d ${computerToolDir} 0700 ${primaryUser} users - -"
    "d ${computerBinDir} 0700 ${primaryUser} users - -"
    "d ${computerCacheDir} 0700 ${primaryUser} users - -"
    "f ${computerStartupLog} 0600 ${primaryUser} users - -"
    "d ${secretsDir} 0700 root root - -"
    "Z ${secretsDir} ~0700 root root - -"
    "z ${hostAdmin.privateKeyPath} 0400 root root - -"
    "z ${hostAdmin.publicKeyPath} 0644 root root - -"
  ];

  environment.systemPackages = [ hostCommand ];

  networking.firewall.allowedTCPPorts = [ computerPort ];

  systemd.services.open-webui-computer = {
    description = "Open WebUI Computer server worker";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "sshd.service"
    ];
    wants = [ "network-online.target" ];

    path = with pkgs; [
      bash
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
      ENABLE_CHAT_RECONCILE_ON_STARTUP = "true";
      UV_TOOL_DIR = computerToolDir;
      UV_TOOL_BIN_DIR = computerBinDir;
      UV_CACHE_DIR = computerCacheDir;
      PATH = "${computerBinDir}:${hostCommand}/bin:/run/current-system/sw/bin:/home/${primaryUser}/.nix-profile/bin";
    };

    unitConfig.AssertPathIsRegular = [ hostAdmin.privateKeyPath ];

    serviceConfig = {
      Type = "simple";
      User = primaryUser;
      Group = "users";
      WorkingDirectory = "/home/${primaryUser}";
      ExecStartPre = installComputer;
      ExecStart = "${computerBinDir}/cptr run --host ${serverCfg.lan.serverIp} --port ${toString computerPort} --headless";
      LoadCredential = "host-admin-key:${hostAdmin.privateKeyPath}";
      Restart = "on-failure";
      RestartSec = "5s";
      UMask = "0077";
      StandardOutput = "append:${computerStartupLog}";
      StandardError = "journal";
    };
  };
}
