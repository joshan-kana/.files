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

  computerVersion = "0.9.21";
  computerPort = 8000;
  computerRoot = "${appDataRoot}/open-webui-computer";
  computerStateDir = "${computerRoot}/state";
  computerToolDir = "${computerRoot}/uv-tools";
  computerBinDir = "${computerRoot}/bin";
  computerCacheDir = "${computerRoot}/uv-cache";
  computerVersionFile = "${computerRoot}/.installed-version";
  computerStartupLog = "${computerRoot}/startup.log";
  computerSecretEnv = "${secretsDir}/open-webui-computer.env";
  computerBaseUrl = "http://${serverCfg.lan.serverIp}:${toString computerPort}";

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

  # Generate a dedicated localhost-only admin key on first activation. Keeping
  # it under /root/secrets makes it persistent without placing key material in
  # Git or the Nix store.
  system.activationScripts.openWebuiHostAdminCredentials = {
    deps = [ "users" ];
    text = ''
      ${pkgs.coreutils}/bin/install -d -m 0700 ${secretsDir}

      if [ ! -s ${hostAdmin.privateKeyPath} ] || [ ! -s ${hostAdmin.publicKeyPath} ]; then
        ${pkgs.coreutils}/bin/rm -f ${hostAdmin.privateKeyPath} ${hostAdmin.publicKeyPath}
        ${pkgs.openssh}/bin/ssh-keygen \
          -q \
          -t ed25519 \
          -N "" \
          -C open-webui-host-admin@nixos-server \
          -f ${hostAdmin.privateKeyPath}
      fi

      ${pkgs.coreutils}/bin/chmod 0400 ${hostAdmin.privateKeyPath}
      ${pkgs.coreutils}/bin/chmod 0644 ${hostAdmin.publicKeyPath}

      home=/home/${hostAdmin.user}
      ${pkgs.coreutils}/bin/install -d -m 0700 -o ${hostAdmin.user} -g users "$home/.ssh"
      ${pkgs.gawk}/bin/awk '{ print "from=\"127.0.0.1,::1\" " $1 " " $2 " open-webui-host-admin@nixos-server" }' \
        ${hostAdmin.publicKeyPath} > "$home/.ssh/authorized_keys"
      ${pkgs.coreutils}/bin/chown ${hostAdmin.user}:users "$home/.ssh/authorized_keys"
      ${pkgs.coreutils}/bin/chmod 0600 "$home/.ssh/authorized_keys"
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
      SEARXNG_BASE_URL = "http://${serverCfg.lan.serverIp}:8888";
      UV_TOOL_DIR = computerToolDir;
      UV_TOOL_BIN_DIR = computerBinDir;
      UV_CACHE_DIR = computerCacheDir;
      PATH = "${computerBinDir}:${hostCommand}/bin:${pkgs.chromium}/bin:/run/current-system/sw/bin:/home/${primaryUser}/.nix-profile/bin";
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

  # First boot is fully unattended: create Computer's local admin from its
  # one-time setup token, register the real server workspaces, enable the local
  # browser + SearXNG, and mint the gateway key that Open WebUI consumes.
  systemd.services.open-webui-computer-bootstrap = {
    description = "Bootstrap Open WebUI Computer server worker";
    wantedBy = [ "multi-user.target" ];
    after = [ "open-webui-computer.service" ];
    requires = [ "open-webui-computer.service" ];
    path = with pkgs; [
      coreutils
      curl
      gnugrep
      jq
      openssl
      python3
    ];
    serviceConfig = {
      Type = "oneshot";
      UMask = "0077";
    };
    script = ''
      set -euo pipefail

      base=${computerBaseUrl}
      envFile=${computerSecretEnv}
      cookies="$(mktemp)"
      trap 'rm -f "$cookies"' EXIT

      for _ in $(seq 1 60); do
        if curl -fsS "$base/api/health" >/dev/null 2>&1; then
          break
        fi
        sleep 1
      done
      curl -fsS "$base/api/health" >/dev/null

      install -d -m 0700 ${secretsDir}
      touch "$envFile"
      chmod 0600 "$envFile"

      get_secret() {
        key="$1"
        sed -n "s/^$key=//p" "$envFile" | tail -n 1
      }

      set_secret() {
        key="$1"
        value="$2"
        tmp="$(mktemp)"
        grep -v "^$key=" "$envFile" > "$tmp" || true
        printf '%s=%s\n' "$key" "$value" >> "$tmp"
        install -m 0400 "$tmp" "$envFile"
        rm -f "$tmp"
      }

      adminPassword="$(get_secret CPTR_ADMIN_PASSWORD)"
      if [ -z "$adminPassword" ]; then
        adminPassword="$(openssl rand -hex 32)"
        set_secret CPTR_ADMIN_PASSWORD "$adminPassword"
      fi

      login() {
        curl -fsS \
          -c "$cookies" \
          -H 'Content-Type: application/json' \
          -d "$(jq -cn --arg u '${primaryUser}' --arg p "$adminPassword" '{username:$u,password:$p}')" \
          "$base/api/auth/login" >/dev/null
      }

      if ! login 2>/dev/null; then
        startupToken="$(grep -Eo 'token=[0-9a-f]{64}' ${computerStartupLog} | tail -n 1 | cut -d= -f2 || true)"
        if [ -z "$startupToken" ]; then
          echo "Computer has an account but the managed bootstrap password cannot log in." >&2
          echo "Restore ${computerSecretEnv}, or reset the Computer admin password before retrying." >&2
          exit 1
        fi

        curl -fsS \
          -c "$cookies" \
          -H 'Content-Type: application/json' \
          -d "$(jq -cn --arg u '${primaryUser}' --arg p "$adminPassword" --arg t "$startupToken" '{username:$u,password:$p,token:$t,display_name:"Joshan"}')" \
          "$base/api/auth/setup" >/dev/null
      fi

      put_workspace() {
        workspace="$1"
        name="$2"
        encoded="$(python -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$workspace")"
        curl -fsS \
          -b "$cookies" \
          -X PUT \
          -H 'Content-Type: application/json' \
          -d "$(jq -cn --arg name "$name" '{name:$name}')" \
          "$base/api/state/workspace?path=$encoded" >/dev/null
      }

      put_workspace "/home/${primaryUser}/.files" ".files"
      put_workspace "/home/${primaryUser}" "nixos-server"

      curl -fsS \
        -b "$cookies" \
        -X PUT \
        -H 'Content-Type: application/json' \
        -d "$(jq -cn --arg searx 'http://${serverCfg.lan.serverIp}:8888' '{config:{"web.enabled":true,"web.search_provider":"searxng","web.searxng_base_url":$searx,"browser.enabled":true,"browser.provider":"local","browser.auto_launch":true,"browser.cdp_url":"http://localhost:9222","browser.tab_default_mode":"chrome","browser.tab_chrome_source":"managed"}}')" \
        "$base/api/admin/config" >/dev/null

      gatewayKey="$(get_secret CPTR_GATEWAY_API_KEY)"
      if [ -n "$gatewayKey" ] \
        && curl -fsS -H "Authorization: Bearer $gatewayKey" "$base/v1/models" >/dev/null 2>&1; then
        :
      else
        gatewayKey="$(
          curl -fsS \
            -b "$cookies" \
            -H 'Content-Type: application/json' \
            -d '{"name":"open-webui-server"}' \
            "$base/v1/keys" | jq -r '.key'
        )"
        test -n "$gatewayKey"
        test "$gatewayKey" != null
        set_secret CPTR_GATEWAY_API_KEY "$gatewayKey"
      fi

      chmod 0400 "$envFile"
    '';
  };
}
