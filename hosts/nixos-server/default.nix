{
  inputs,
  moduleRegistry,
  modulesPath,
  ...
}:

{
  imports = [
    inputs.nixos-hardware.nixosModules.raspberry-pi-4
    ./options.nix
    (import ../../modules/virtualisation/containers/image-locking.nix {
      lockFile = ./container-images.lock;
    })
    "${modulesPath}/image/repart.nix"
  ];

  dotfiles = {
    profile.name = "nixos-server";
    scopes.virtualisation = {
      libvirt.enable = false;
      quickemu.enable = false;
      distrobox.enable = false;
      bottles.enable = false;
      vm.aliases.enable = false;
    };
    scopes.cli = {
      clipboard.enable = false;
      mpv.enable = false;
      tmuxai.enable = false;
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

  inherit (moduleRegistry)
    system
    theme
    cli
    serverApps
    ;
  nix =
    {
      config,
      inputs,
      ...
    }:
    (moduleRegistry.nix { inherit config; })
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
      lan = config.dotfiles.server.lan;
      lanPrefixLength = builtins.elemAt (lib.splitString "/" lan.subnet) 1;
    in
    {
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

      networking.networkmanager.enable = true;
      networking.networkmanager.ensureProfiles.profiles."wired-static" = {
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
        };
        ipv6.method = "auto";
      };

      services.avahi = {
        enable = true;
        nssmdns4 = true;
        openFirewall = true;
      };

      inherit ((moduleRegistry.networking { })) ssh;

      dns =
        {
          config,
          lib,
          ...
        }:

        let
          serverCfg = config.dotfiles.server;
          appDataRoot = serverCfg.storage.appData.root;
          inherit (serverCfg) lan;
          lanPrefixLength = builtins.elemAt (lib.splitString "/" lan.subnet) 1;
          hostDns = "${lib.concatStringsSep ";" ([ lan.dns.serviceIp ] ++ lan.dns.fallbackServers)};";

          service = {
            user = "adguardhome";
            group = "appdata-editors";
            ip = lan.dns.serviceIp;
            port = 53;
            dataDir = "${appDataRoot}/adguard";
            workDir = "${appDataRoot}/adguard/work";
            confDir = "${appDataRoot}/adguard/conf";
            configFile = "${appDataRoot}/adguard/conf/AdGuardHome.yaml";
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
          ...
        }:

        let
          serverCfg = config.dotfiles.server;
        in
        {
          services.tailscale = {
            enable = true;
            openFirewall = true;
            useRoutingFeatures = "server";
            authKeyFile = "${serverCfg.secretsDir}/tailscale-oauth-client-secret";
            authKeyParameters = {
              ephemeral = true;
              preauthorized = true;
            };
            extraDaemonFlags = [
              "--state=mem:"
            ];
            extraUpFlags = [
              "--advertise-tags=tag:nixos-server"
              "--hostname=${config.networking.hostName}"
              "--advertise-routes=${serverCfg.lan.subnet}"
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
          };
        };
    };
  virtualisation =
    {
      config,
      pkgs,
      ...
    }:
    let
      shared = moduleRegistry.virtualisation { inherit config pkgs; };
    in
    shared
    // {
      containers =
        { config, ... }:
        (shared.containers { inherit config; })
        // {
          virtualisation.oci-containers.backend = "docker";
        };

      vm =
        _:
        (shared.vm { })
        // {
          safety =
            { lib, ... }:

            {
              virtualisation.vmVariant = {
                services.restic.backups = lib.mkForce { };
                services.snapper.configs = lib.mkForce { };

                # VM builds do not have the real Vault pool or LAN interface used by the
                # production Raspberry Pi deployment.
                systemd.services.docker-network-adguard = lib.mkForce { };

                systemd.services.docker-adguard = {
                  after = lib.mkForce [ "docker.service" ];
                  requires = lib.mkForce [ "docker.service" ];
                };

                virtualisation.oci-containers.containers.adguard.extraOptions = lib.mkForce [ ];
                virtualisation.oci-containers.containers.adguard.ports = [
                  "53:53/tcp"
                  "53:53/udp"
                  "3000:3000/tcp"
                ];
              };
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
      cfg = config.dotfiles.server.storage;
      inherit (cfg) snapshots;
      appDataRoot = cfg.appData.root;
      pool = cfg.dataRoot.poolName;
      secretsDir = config.dotfiles.server.secretsDir;
      snapshotInterval = "*:0/${toString snapshots.intervalMinutes}";
      resticWrapperCommands = lib.pipe config.services.restic.backups [
        (lib.filterAttrs (_: backup: backup.createWrapper))
        lib.attrNames
        (map (name: "restic-${name}"))
      ];
    in
    {
      assertions = [
        {
          assertion = snapshots.intervalMinutes <= 60 && lib.mod 60 snapshots.intervalMinutes == 0;
          message = "dotfiles.server.storage.snapshots.intervalMinutes must divide one hour evenly.";
        }
      ];

      users = {
        groups = {
          ${cfg.appData.group.name}.gid = cfg.appData.group.id;
          ${cfg.dataRoot.group.name} = { };
        };
        users.${config.dotfiles.users.primary.name}.extraGroups = [
          cfg.appData.group.name
          cfg.dataRoot.group.name
        ];
      };

      environment.systemPackages = with pkgs; [
        restic
        rclone
      ];

      boot = {
        supportedFilesystems = [
          "btrfs"
          "zfs"
        ];
        zfs.extraPools = [ pool ];
        zfs.forceImportRoot = false;
      };

      services.zfs = {
        autoScrub = {
          enable = true;
          pools = [ pool ];
          interval = cfg.dataRoot.scrubInterval;
        };
        trim.enable = false;
      };

      services.sanoid = {
        enable = true;
        interval = snapshotInterval;
        templates.vault = {
          frequent_period = snapshots.intervalMinutes;
          frequently = 60 / snapshots.intervalMinutes;
          inherit (snapshots.retention)
            hourly
            daily
            weekly
            monthly
            ;
          autosnap = true;
          autoprune = true;
        };
        datasets."${pool}/data" = {
          useTemplate = [ "vault" ];
          recursive = "zfs";
        };
      };

      services.snapper = {
        inherit snapshotInterval;
        cleanupInterval = "1h";
        persistentTimer = true;
        configs.apps = {
          SUBVOLUME = appDataRoot;
          FSTYPE = "btrfs";
          FREE_LIMIT = config.nix.settings.min-free;
          TIMELINE_CREATE = true;
          TIMELINE_CLEANUP = true;
          TIMELINE_LIMIT_HOURLY = snapshots.retention.hourly;
          TIMELINE_LIMIT_DAILY = snapshots.retention.daily;
          TIMELINE_LIMIT_WEEKLY = snapshots.retention.weekly;
          TIMELINE_LIMIT_MONTHLY = snapshots.retention.monthly;
        };
      };

      services.restic.backups.apps = {
        initialize = true;
        repository = "rclone:dropbox:Archives/Backups/nixos-server";
        passwordFile = "${secretsDir}/restic-password";
        rcloneConfigFile = "${secretsDir}/rclone.conf";
        paths = [ appDataRoot ];
        exclude = [
          "${appDataRoot}/.snapshots"
        ];
        pruneOpts = [
          "--keep-hourly ${toString snapshots.retention.hourly}"
          "--keep-daily ${toString snapshots.retention.daily}"
          "--keep-weekly ${toString snapshots.retention.weekly}"
          "--keep-monthly ${toString snapshots.retention.monthly}"
        ];
        timerConfig = {
          OnCalendar = "*:0/30";
          Persistent = true;
          RandomizedDelaySec = "5m";
        };
        checkOpts = [ "--read-data-subset=1G" ];
      };

      systemd.tmpfiles.rules = [
        "d ${appDataRoot} 2770 root ${cfg.appData.group.name} - -"
        "v ${appDataRoot}/.snapshots 0750 root root - -"
        "a ${appDataRoot}/.snapshots - - - - u::rwx,g::r-x,o::---,d:u::rwx,d:g::r-x,d:o::---"
      ];

      programs.zsh.interactiveShellInit =
        lib.mkIf (config.programs.zsh.enable && resticWrapperCommands != [ ])
          (
            lib.mkAfter ''
              autoload -Uz _restic
              compdef _restic ${lib.escapeShellArgs resticWrapperCommands}
            ''
          );
    };
  image = import ./image.nix;
  hardware = import ./hardware.nix;
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
        substituters = [ "https://nixos-raspberrypi.cachix.org" ];
        trusted-public-keys = [
          "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
        ];
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

    let
      primaryUser = config.dotfiles.users.primary.name;
    in
    {
      users.users.${primaryUser}.openssh.authorizedKeys.keys = [
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
