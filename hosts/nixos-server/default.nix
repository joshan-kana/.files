{
  editScope,
  inputs,
  moduleRegistry,
  ...
}:

{
  inherit (moduleRegistry)
    system
    theme
    cli
    serverApps
    ;

  imports = [
    inputs.hermes-agent.nixosModules.default
    ./options.nix
    ./hardware.nix
    (import ../../modules/virtualisation/containers/image-locking.nix {
      lockFile = ./container-images.lock;
    })
  ];

  dotfiles = {
    profile.name = "nixos-server";
    scopes.serverApps.ntfy.comin.enable = true;
    scopes.virtualisation = {
      children.enable = false;
      containers.enable = true;
      vm.enable = true;
    };
    scopes.cli = {
      systemCommands.vm.enable = false;
      clipboard.enable = false;
      mpv.enable = false;
      ollama.enable = false;
      cava.enable = false;
      ncmpcpp.enable = false;
      youtubeTui.enable = false;
      stow.enable = false;
      killall.enable = false;
      xdgUtils.enable = false;
      trashCli.enable = false;
      gnumake.enable = false;
      devbox.enable = false;
      has.enable = false;
      nvd.enable = false;
      nixTree.enable = false;
      python3.enable = false;
    };
  };

  backups = editScope moduleRegistry.backups {
    secrets =
      {
        config,
        inherited,
        ...
      }:
      {
        services.restic.backups.secrets.paths = [
          config.dotfiles.server.secretsDir
        ]
        ++ inherited.services.restic.backups.secrets.paths
        ++ [
          "/etc/passwd"
          "/etc/group"
          "/etc/shadow"
        ];

        systemd.tmpfiles.rules = inherited.systemd.tmpfiles.rules ++ [
          "d ${config.dotfiles.server.secretsDir} 0700 root root - -"
          "Z ${config.dotfiles.server.secretsDir} ~0700 root root - -"
        ];
      };
  };
  nix =
    {
      config,
      inputs,
      pkgs,
      ...
    }:
    (moduleRegistry.nix { inherit config inputs pkgs; })
    // {
      home-manager.sharedModules = [
        "${inputs.home-manager}/modules/programs/attic-client.nix"
      ];
      users.users.${config.dotfiles.users.primary.name}.linger = true;
    };
  networking =
    {
      config,
      lib,
      pkgs,
      ...
    }:

    let
      shared = moduleRegistry.networking { };
      inherit (config.dotfiles.server) lan;
      lanPrefixLength = builtins.elemAt (lib.splitString "/" lan.subnet) 1;
    in
    shared
    // {
      # Stable machine identifier required for safe ZFS pool imports.
      networking.hostId = "fa3f98bb";

      # Prevent ARP flux when multiple interfaces participate in the same LAN.
      # Each interface should answer ARP only for addresses assigned to itself.
      boot.kernel.sysctl = {
        "net.ipv4.conf.all.arp_ignore" = 1;
        "net.ipv4.conf.default.arp_ignore" = 1;
        "net.ipv4.conf.all.arp_announce" = 2;
        "net.ipv4.conf.default.arp_announce" = 2;
      };

      environment.systemPackages = with pkgs; [
        iproute2
      ];

      networkManager =
        _:
        lib.recursiveUpdate (shared.networkManager { }) {
          networking.networkmanager = {
            settings.main."ignore-carrier" = "*";
            ensureProfiles.profiles."wired-static" = {
              connection = {
                id = "wired-static";
                type = "ethernet";
                "interface-name" = lan.interface;
                autoconnect = true;
                "autoconnect-priority" = 100;
              };
              ipv4 = {
                method = "manual";
                address1 = "${lan.serverIp}/${lanPrefixLength},${lan.gateway}";
                "may-fail" = false;
              };
              ipv6.method = "auto";
            };
          };
        };

      dns =
        {
          config,
          lib,
          ...
        }:

        let
          inherit (config.dotfiles) server;
          lanPrefixLength = builtins.elemAt (lib.splitString "/" server.lan.subnet) 1;
          hostDns = "${
            lib.concatStringsSep ";" ([ server.lan.dns.serviceIp ] ++ server.lan.dns.fallbackServers)
          };";

          service = {
            user = "adguardhome";
            group = "appdata-editors";
            ip = server.lan.dns.serviceIp;
            port = 53;
            dataDir = "${server.storage.appData.root}/adguard";
            workDir = "${server.storage.appData.root}/adguard/work";
            confDir = "${server.storage.appData.root}/adguard/conf";
            configFile = "${server.storage.appData.root}/adguard/conf/AdGuardHome.yaml";
          };
        in
        {
          networking.networkmanager.ensureProfiles.profiles."wired-static" = {
            ipv4 = {
              address2 = "${service.ip}/${lanPrefixLength}";
              dns = hostDns;
              "ignore-auto-dns" = true;
            };
            ipv6."ignore-auto-dns" = true;
          };

          networking.firewall.allowedTCPPorts = [ service.port ];
          networking.firewall.allowedUDPPorts = [ service.port ];

          users.users.${service.user} = {
            isSystemUser = true;
            inherit (service) group;
          };

          systemd.tmpfiles.rules = [
            "d ${service.dataDir} 2750 ${service.user} ${service.group} - -"
            "d ${service.workDir} 2750 ${service.user} ${service.group} - -"
            "d ${service.confDir} 2750 ${service.user} ${service.group} - -"
            "Z ${service.dataDir} - ${service.user} ${service.group} - -"
            "z ${service.configFile} 0660 ${service.user} ${service.group} - -"
          ];

          services.adguardhome = {
            enable = true;

            # Opens the AdGuard Home web UI port only.
            # DNS port 53 is still opened manually above.
            openFirewall = true;

            # Keep UI-edited settings, but force the critical bind settings from Nix.
            mutableSettings = true;

            # Web UI only on the dedicated LAN DNS service IP.
            # Port is intentionally omitted because the module default is 3000.
            host = service.ip;

            extraArgs = [
              "--work-dir ${service.workDir}"
              "--config ${service.configFile}"
            ];

            settings = {
              dns = {
                # DNS only on the dedicated service IP and localhost, not 192.168.1.3.
                bind_hosts = [
                  service.ip
                  "127.0.0.1"
                ];
                inherit (service) port;
              };
            };
          };

          systemd.services.adguardhome = {
            after = [
              "network-online.target"
            ];
            wants = [ "network-online.target" ];

            serviceConfig = {
              DynamicUser = lib.mkForce false;
              User = service.user;
              Group = service.group;

              StateDirectory = lib.mkForce "apps/adguard/conf";
              StateDirectoryMode = "2750";
              UMask = lib.mkForce "0007";

              # AdGuard writes runtime databases such as work/data/sessions.db here.
              ReadWritePaths = [ service.workDir ];
            };
          };
        };

      tailscale =
        {
          config,
          lib,
          pkgs,
          ...
        }:

        let
          inherit (config.dotfiles) server;
        in
        {
          networking.firewall.trustedInterfaces = [ config.services.tailscale.interfaceName ];

          services.tailscale = {
            enable = true;
            openFirewall = true;
            useRoutingFeatures = "server";
            authKeyFile = "${server.secretsDir}/tailscale-oauth-client-secret";
            authKeyParameters = {
              ephemeral = true;
              preauthorized = true;
            };
            extraDaemonFlags = [
              "--state=mem:"
              "--statedir=/var/lib/tailscale"
            ];
            extraUpFlags = [
              "--advertise-tags=tag:nixos-server"
              "--hostname=${config.networking.hostName}"
              "--advertise-routes=${server.lan.subnet}"
              "--accept-dns=false"
            ];
            extraSetFlags = [ ];
          };

          # Keep the server's ephemeral Tailscale behaviour, but do not make
          # fresh Tailscale authentication block multi-user boot.
          #
          # The daemon still starts during boot. The auth/connect step still runs
          # automatically, but after multi-user.target so LAN boot is not held up by
          # Tailscale control-plane/auth latency.
          systemd.services.tailscaled-autoconnect = {
            after = lib.mkForce [
              "tailscaled.service"
              "multi-user.target"
            ];
            before = lib.mkForce [ "shutdown.target" ];
            preStart = ''
              if ${config.services.tailscale.package}/bin/tailscale status --json 2>/dev/null |
                ${pkgs.jq}/bin/jq -e '.BackendState == "Running"' >/dev/null; then
                exit 0
              fi

              token="$(${pkgs.curl}/bin/curl -fsS --max-time 5 \
                --data-urlencode "client_id=$(cat ${server.secretsDir}/tailscale-oauth-client-id)" \
                --data-urlencode "client_secret=$(cat ${server.secretsDir}/tailscale-oauth-client-secret)" \
                --data-urlencode "scope=devices:core" \
                --data-urlencode "tags=tag:nixos-server" \
                https://api.tailscale.com/api/v2/oauth/token | \
                ${pkgs.jq}/bin/jq -er .access_token)"

              ${pkgs.curl}/bin/curl -fsS --max-time 5 -u "$token:" \
                'https://api.tailscale.com/api/v2/tailnet/-/devices?isEphemeral=true&tags=tag%3Anixos-server' | \
                ${pkgs.jq}/bin/jq -r \
                  '.devices[] | select(.hostname == "${config.networking.hostName}") | .nodeId' | \
                while read -r id; do
                  ${pkgs.curl}/bin/curl -fsS --max-time 5 -X DELETE -u "$token:" \
                    "https://api.tailscale.com/api/v2/device/$id" >/dev/null
                done
            '';
            serviceConfig = {
              Restart = "on-failure";
              RestartSec = "10s";
            };
          };

          calendarSync =
            { config, ... }:
            let
              inherit (config.dotfiles) server;
              webhookPath = "youtrack-calendar-a5c05b8c08849e7c2f7c";
            in
            {
              systemd.services.tailscale-funnel-youtrack-calendar = {
                description = "Expose the YouTrack calendar sync webhook through Tailscale Funnel";
                after = [
                  "tailscaled-autoconnect.service"
                  "docker-n8n.service"
                ];
                wants = [ "docker-n8n.service" ];
                wantedBy = [ "tailscaled-autoconnect.service" ];
                script = ''
                  ${config.services.tailscale.package}/bin/tailscale funnel \
                    --bg \
                    --yes \
                    --https=443 \
                    --set-path=/webhook/${webhookPath} \
                    http://${server.lan.serverIp}:5678/webhook/${webhookPath}
                '';
                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                };
              };
            };
        };
    };
  virtualisation = editScope moduleRegistry.virtualisation {
    containers = _: {
      virtualisation.oci-containers.backend = "docker";
    };

    vm = { lib, ... }: {
      virtualisation.vmVariant = {
        services.restic.backups = lib.mkForce { };
        services.snapper.configs = lib.mkForce { };

        # The VM does not have the dedicated LAN address used by native AdGuard.
        services.adguardhome.enable = lib.mkForce false;
      };
    };
  };
  storage =
    {
      config,
      lib,
      pkgs,
      ...
    }:

    let
      inherit (config.dotfiles) server;
      inherit (config.dotfiles.backups) retention;
      inherit (config.dotfiles.users) primary;
      inherit (server) storage;
      backupRcloneConfig = "/var/lib/backup-credentials/rclone.conf";
      snapshotInterval = "*:0/${toString storage.snapshots.intervalMinutes}";
      resticUnlock = ''
        #!${pkgs.runtimeShell}
        ${pkgs.restic}/bin/restic unlock
      '';
    in
    {
      assertions = [
        {
          assertion =
            storage.snapshots.intervalMinutes <= 60 && lib.mod 60 storage.snapshots.intervalMinutes == 0;
          message = "dotfiles.server.storage.snapshots.intervalMinutes must divide one hour evenly.";
        }
      ];

      users = {
        groups = {
          ${storage.appData.group.name}.gid = storage.appData.group.id;
          ${storage.dataRoot.group.name}.gid = storage.dataRoot.group.id;
        };

        users.${primary.name}.extraGroups = [
          storage.appData.group.name
          storage.dataRoot.group.name
        ];
      };

      environment.systemPackages = with pkgs; [ acl ];

      boot = {
        supportedFilesystems = [
          "btrfs"
          "zfs"
        ];
        zfs.extraPools = [ storage.dataRoot.poolName ];
        zfs.forceImportRoot = false;
      };

      services.userborn.enable = true;

      services.zfs = {
        autoScrub = {
          enable = true;
          pools = [ storage.dataRoot.poolName ];
          interval = storage.dataRoot.scrubInterval;
        };
        trim.enable = false;
      };

      services.sanoid = {
        enable = true;
        interval = snapshotInterval;
        templates.vault = {
          frequent_period = storage.snapshots.intervalMinutes;
          frequently = 60 / storage.snapshots.intervalMinutes;
          inherit (retention)
            hourly
            daily
            weekly
            monthly
            ;
          autosnap = true;
          autoprune = true;
        };
        datasets."${storage.dataRoot.poolName}/data" = {
          useTemplate = [ "vault" ];
          recursive = "zfs";
        };
      };

      services.snapper = {
        inherit snapshotInterval;
        cleanupInterval = "1h";
        persistentTimer = true;
        configs.apps = {
          SUBVOLUME = storage.appData.root;
          FSTYPE = "btrfs";
          FREE_LIMIT = config.nix.settings.min-free;
          TIMELINE_CREATE = true;
          TIMELINE_CLEANUP = true;
          TIMELINE_LIMIT_HOURLY = retention.hourly;
          TIMELINE_LIMIT_DAILY = retention.daily;
          TIMELINE_LIMIT_WEEKLY = retention.weekly;
          TIMELINE_LIMIT_MONTHLY = retention.monthly;
        };
      };

      services.restic.backups = {
        apps = {
          repository = "rclone:dropbox:Archives/Backups/nixos-server";
          backupPrepareCommand = resticUnlock;
          passwordFile = "${server.secretsDir}/restic-password";
          rcloneConfigFile = backupRcloneConfig;
          paths = [ storage.appData.root ];
          exclude = [
            "${storage.appData.root}/.snapshots"
          ];
          pruneOpts = [
            "--keep-hourly ${toString retention.hourly}"
            "--keep-daily ${toString retention.daily}"
            "--keep-weekly ${toString retention.weekly}"
            "--keep-monthly ${toString retention.monthly}"
          ];
          timerConfig = {
            OnCalendar = "*:0/30";
            Persistent = true;
            RandomizedDelaySec = "5m";
          };
          checkOpts = [ "--read-data-subset=1G" ];
        };
      };

      systemd.tmpfiles.rules = [
        "d ${storage.appData.root} 2770 root ${storage.appData.group.name} - -"
        "a+ ${storage.appData.root} - - - - u:${primary.name}:rwx,g:${storage.appData.group.name}:rwx,d:u:${primary.name}:rwx,d:g:${storage.appData.group.name}:rwx"
        "a+ ${storage.dataRoot.path} - - - - u:${primary.name}:rwx,g:${storage.dataRoot.group.name}:rwx,d:u:${primary.name}:rwx,d:g:${storage.dataRoot.group.name}:rwx"
        "v ${storage.appData.root}/.snapshots 0750 root root - -"
        "a ${storage.appData.root}/.snapshots - - - - u::rwx,g::r-x,o::---,d:u::rwx,d:g::r-x,d:o::---"
      ];
    };
  maintenance =
    { pkgs, ... }:

    let
      cleanupRetentionDays = 7;
      cleanupSchedule = "weekly";
      minFree = "2G";
    in
    {
      nix.gc = {
        automatic = true;
        dates = cleanupSchedule;
        options = "--delete-older-than ${toString cleanupRetentionDays}d";
      };

      nix.optimise = {
        automatic = true;
        dates = [ cleanupSchedule ];
      };

      nix.settings = {
        min-free = minFree;
      };

      services.journald.extraConfig = ''
        SystemMaxUse=1G
        SystemKeepFree=${minFree}
        MaxRetentionSec=${toString cleanupRetentionDays}day
      '';

      virtualisation.docker.autoPrune = {
        enable = true;
        dates = cleanupSchedule;
        flags = [
          "--all"
          "--filter=until=${toString (cleanupRetentionDays * 24)}h"
        ];
      };

      environment.systemPackages = with pkgs; [
        curl
        jq
        rsync
      ];
    };
  access =
    {
      config,
      lib,
      ...
    }:

    {
      home = _: {
        programs.ssh = {
          enable = true;
          enableDefaultConfig = false;
          settings."github.com" = {
            IdentityFile = "${config.dotfiles.secretsDir}/id_ed25519";
            IdentitiesOnly = true;
          };
        };
      };

      users.users.${config.dotfiles.users.primary.name}.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGMZdbT05P/naiv07J32DxHDOR5A1z8F9jijeBrDkXWV joshankana@gmail.com"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4kCJGHE5VF6YL3Y2almpG/0cl7+h2mMrSRONRXIhZr Shortcuts on Joshan’s iPhone"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH2MhLVRuFAl9pssk8T3uxTr332TGoZMqjSoOLGudXpO Joshan's iPhone"
      ];

      security.pam.sshAgentAuth = {
        enable = true;
        authorizedKeysFiles = [
          "/etc/sudo-authorized-key"
        ];
      };

      security.sudo = {
        extraConfig = ''
          Defaults:joshan noninteractive_auth
        '';
        wheelNeedsPassword = true;
      };

      systemd.tmpfiles.rules = [
        "f+ /etc/sudo-authorized-key 0444 root root - ${
          lib.concatStringsSep "\\n" [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIjtOri4c/7Nw3CMsv+ADMgepdVBTvtBlrTSJR+w5r7s joshan@nixos-server-sudo"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH2MhLVRuFAl9pssk8T3uxTr332TGoZMqjSoOLGudXpO Joshan's iPhone"
          ]
        }\\n"
      ];
    };

  compatibility = _: {
    system.stateVersion = "25.05";
  };

}
