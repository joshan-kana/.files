{
  configurations,
  lib,
  pkgs,
  semanticScopeOptions,
  source,
}:

let
  hostNames = builtins.attrNames configurations;
  server = configurations.nixos-server;
  serverConfig = server.config;

  allScopeOptions = semanticScopeOptions.nixdOptions configurations;
  hostOptionTrees = map (
    name: semanticScopeOptions.nixdHostOptions configurations configurations.${name}
  ) hostNames;
  mergedHostOptions = lib.foldl' lib.recursiveUpdate { } hostOptionTrees;
  projectOptions = {
    dotfiles =
      (builtins.removeAttrs mergedHostOptions.dotfiles [
        "scopes"
        "resolvedScopes"
      ])
      // {
        scopes = allScopeOptions.dotfiles.scopes;
      };
  };

  optionDocs = pkgs.nixosOptionsDoc {
    options = projectOptions;
  };
  optionDocsCommonMark = optionDocs.optionsCommonMark.overrideAttrs {
    extraArgs = [
      "--anchor-style"
      "legacy"
      "--anchor-prefix"
      "opt-"
    ];
  };

  scopeChildren = tree: lib.filterAttrs (_: value: builtins.isAttrs value && value ? enable) tree;
  flattenScopes =
    prefix: tree:
    lib.concatMap (
      name:
      let
        node = tree.${name};
        path = prefix ++ [ name ];
      in
      [
        {
          inherit path;
          enabled = node.enable;
        }
      ]
      ++ flattenScopes path (scopeChildren node)
    ) (builtins.attrNames (scopeChildren tree));

  hostScopeRows = lib.mapAttrs (
    _: host: flattenScopes [ ] host.config.dotfiles.resolvedScopes
  ) configurations;
  allScopeNames = lib.unique (
    lib.concatMap (rows: map (row: lib.concatStringsSep "." row.path) rows) (
      builtins.attrValues hostScopeRows
    )
  );

  scopeEnabled =
    hostName: scopeName:
    lib.any (
      row: lib.concatStringsSep "." row.path == scopeName && row.enabled
    ) hostScopeRows.${hostName};

  filesystem = config: mountPoint: lib.attrByPath [ mountPoint ] null config.fileSystems;
  packageNames = packages: lib.sort builtins.lessThan (lib.unique (map lib.getName packages));
  codeList =
    values:
    if values == [ ] then
      "_None_"
    else
      lib.concatStringsSep ", " (map (value: "`${toString value}`") values);
  cellList =
    values:
    if values == [ ] then
      "_None_"
    else
      lib.concatStringsSep "<br>" (map (value: "`${toString value}`") values);
  bulletList =
    values:
    if values == [ ] then
      "- _None_"
    else
      lib.concatMapStringsSep "\n" (value: "- `${toString value}`") values;
  yesNo = value: if value then "yes" else "no";
  optionalCode = value: if value == null || value == "" then "_None_" else "`${toString value}`";
  portRanges =
    values:
    if values == [ ] then
      "_None_"
    else
      lib.concatStringsSep ", " (map (range: "${toString range.from}-${toString range.to}") values);
  htmlEscape = value: lib.replaceStrings [ "&" "<" ">" ] [ "&amp;" "&lt;" "&gt;" ] value;
  htmlPackageList =
    values:
    if values == [ ] then
      "<p><em>None</em></p>"
    else
      "<ul>\n${
        lib.concatMapStringsSep "\n" (value: "<li><code>${htmlEscape value}</code></li>") values
      }\n</ul>";

  scopeTableHeader = "| Scope | ${lib.concatStringsSep " | " hostNames} |\n| --- | ${
    lib.concatStringsSep " | " (map (_: "---:") hostNames)
  } |";
  scopeTableRows = map (
    scopeName:
    "| `${scopeName}` | ${
      lib.concatStringsSep " | " (
        map (hostName: if scopeEnabled hostName scopeName then "✓" else "") hostNames
      )
    } |"
  ) (lib.sort builtins.lessThan allScopeNames);

  enabledScopeNames =
    hostName:
    map (row: lib.concatStringsSep "." row.path) (
      lib.filter (row: row.enabled) hostScopeRows.${hostName}
    );
  topLevelScopeNames =
    hostName:
    map (row: builtins.head row.path) (
      lib.filter (row: row.enabled && builtins.length row.path == 1) hostScopeRows.${hostName}
    );
  enabledServerApps =
    config:
    let
      root = lib.attrByPath [ "serverApps" ] { } config.dotfiles.resolvedScopes;
    in
    lib.sort builtins.lessThan (
      lib.filter (
        name:
        let
          node = root.${name};
        in
        builtins.isAttrs node && node ? enable && node.enable
      ) (builtins.attrNames root)
    );

  hostFacts = lib.mapAttrs (
    name: host:
    let
      inherit (host) config;
      primaryUser = config.dotfiles.users.primary;
      firewall = config.networking.firewall;
      resticJobs = lib.mapAttrsToList (backupName: backup: {
        name = backupName;
        repository = toString backup.repository;
        paths = backup.paths or [ ];
        exclude = backup.exclude or [ ];
        schedule = backup.timerConfig.OnCalendar or null;
        pruneOpts = backup.pruneOpts or [ ];
        checkOpts = backup.checkOpts or [ ];
      }) config.services.restic.backups;
      backupJobs = builtins.filter (backup: backup.paths != [ ]) resticJobs;
      maintenanceJobs = builtins.filter (
        backup: backup.paths == [ ] && (backup.pruneOpts != [ ] || backup.checkOpts != [ ])
      ) resticJobs;
      filesystems = lib.mapAttrsToList (mountPoint: fs: {
        inherit mountPoint;
        device = toString fs.device;
        inherit (fs) fsType;
        options = fs.options or [ ];
      }) config.fileSystems;
      firewallInterfaces = lib.mapAttrsToList (interfaceName: interface: {
        name = interfaceName;
        tcpPorts = interface.allowedTCPPorts;
        udpPorts = interface.allowedUDPPorts;
        tcpPortRanges = interface.allowedTCPPortRanges;
        udpPortRanges = interface.allowedUDPPortRanges;
      }) firewall.interfaces;
      hasServerLan = lib.hasAttrByPath [ "dotfiles" "server" "lan" ] config;
      hasServerStorage = lib.hasAttrByPath [ "dotfiles" "server" "storage" ] config;
      systemPackages = packageNames config.environment.systemPackages;
      homePackages = packageNames config.home-manager.users.${primaryUser.name}.home.packages;
    in
    {
      system = host.pkgs.stdenv.hostPlatform.system;
      profile = config.dotfiles.profile.name;
      hostName = config.networking.hostName;
      primaryUser = primaryUser.name;
      primaryHome = "${primaryUser.homeRoot}/${primaryUser.name}";
      repoPath = config.dotfiles.paths.repoPath;
      inherit
        filesystems
        systemPackages
        homePackages
        backupJobs
        maintenanceJobs
        firewallInterfaces
        ;
      networking = {
        networkManager = config.networking.networkmanager.enable;
        useDHCP = config.networking.useDHCP;
        nameservers = config.networking.nameservers;
        profiles = builtins.attrNames config.networking.networkmanager.ensureProfiles.profiles;
      };
      firewall = {
        inherit (firewall) enable;
        inherit (firewall) trustedInterfaces;
        tcpPorts = firewall.allowedTCPPorts;
        udpPorts = firewall.allowedUDPPorts;
        tcpPortRanges = firewall.allowedTCPPortRanges;
        udpPortRanges = firewall.allowedUDPPortRanges;
      };
      retention = config.dotfiles.backups.retention;
      containers = builtins.attrNames config.virtualisation.oci-containers.containers;
      serverApps = enabledServerApps config;
      enabledScopes = enabledScopeNames name;
      topLevelScopes = topLevelScopeNames name;
      serverLan =
        if hasServerLan then
          let
            lan = config.dotfiles.server.lan;
          in
          {
            inherit (lan)
              interface
              subnet
              gateway
              serverIp
              ;
            dnsIp = lan.dns.serviceIp;
          }
        else
          null;
      managedStorage =
        if hasServerStorage then
          let
            storage = config.dotfiles.server.storage;
          in
          {
            appDataRoot = storage.appData.root;
            dataRoot = storage.dataRoot.path;
            dataPool = storage.dataRoot.poolName;
            snapshotIntervalMinutes = storage.snapshots.intervalMinutes;
          }
        else
          null;
    }
  ) configurations;

  storage = serverConfig.dotfiles.server.storage;
  lan = serverConfig.dotfiles.server.lan;
  immichMediaRoot = serverConfig.services.immich.mediaLocation;
  paperlessDataRoot = serverConfig.services.paperless.dataDir;
  paperlessMediaRoot = serverConfig.services.paperless.mediaDir;
  paperlessConsumeRoot = serverConfig.services.paperless.consumptionDir;
  paperlessBackupRoot = serverConfig.services.postgresqlBackup.location;

  filesystemTable =
    facts:
    if facts.filesystems == [ ] then
      "_None configured._"
    else
      ''
        | Mount | Device | Filesystem | Options |
        | --- | --- | --- | --- |
        ${lib.concatMapStringsSep "\n" (
          fs: "| `${fs.mountPoint}` | `${fs.device}` | `${fs.fsType}` | ${cellList fs.options} |"
        ) facts.filesystems}
      '';

  firewallInterfaceTable =
    facts:
    if facts.firewallInterfaces == [ ] then
      "_No interface-specific rules._"
    else
      ''
        | Interface | TCP | UDP | TCP ranges | UDP ranges |
        | --- | --- | --- | --- | --- |
        ${lib.concatMapStringsSep "\n" (
          interface:
          "| `${interface.name}` | ${codeList interface.tcpPorts} | ${codeList interface.udpPorts} | ${portRanges interface.tcpPortRanges} | ${portRanges interface.udpPortRanges} |"
        ) facts.firewallInterfaces}
      '';

  backupTable =
    facts:
    if facts.backupJobs == [ ] then
      "_None configured._"
    else
      ''
        | Job | Repository | Schedule | Paths |
        | --- | --- | --- | --- |
        ${lib.concatMapStringsSep "\n" (
          backup:
          "| `${backup.name}` | `${backup.repository}` | ${optionalCode backup.schedule} | ${cellList backup.paths} |"
        ) facts.backupJobs}
      '';

  fleetMarkdown = ''
    # Fleet

    | Host | Platform | Backup jobs | Server apps | System packages | Home packages |
    | --- | --- | ---: | ---: | ---: | ---: |
    ${lib.concatMapStringsSep "\n" (
      name:
      let
        facts = hostFacts.${name};
      in
      "| `${name}` | `${facts.system}` | ${toString (builtins.length facts.backupJobs)} | ${toString (builtins.length facts.serverApps)} | ${toString (builtins.length facts.systemPackages)} | ${toString (builtins.length facts.homePackages)} |"
    ) hostNames}
  '';

  semanticScopesMarkdown = ''
    # Semantic scopes

    ${scopeTableHeader}
    ${lib.concatStringsSep "\n" scopeTableRows}
  '';

  systemMarkdown =
    name:
    let
      facts = hostFacts.${name};
    in
    ''
      # `${name}`

      ## Identity

      | Setting | Evaluated value |
      | --- | --- |
      | Platform | `${facts.system}` |
      | Profile | `${facts.profile}` |
      | Hostname | `${facts.hostName}` |
      | Primary user | `${facts.primaryUser}` |
      | Primary home | `${facts.primaryHome}` |
      | Repository | `${facts.repoPath}` |

      ## Filesystems

      ${filesystemTable facts}

      ## Networking

      | Setting | Evaluated value |
      | --- | --- |
      | NetworkManager | ${yesNo facts.networking.networkManager} |
      | Global DHCP | ${yesNo facts.networking.useDHCP} |
      | Nameservers | ${codeList facts.networking.nameservers} |
      | Managed profiles | ${codeList facts.networking.profiles} |

      ${lib.optionalString (facts.serverLan != null) ''
        ### Managed LAN

        | Setting | Evaluated value |
        | --- | --- |
        | Interface | `${facts.serverLan.interface}` |
        | Subnet | `${facts.serverLan.subnet}` |
        | Gateway | `${facts.serverLan.gateway}` |
        | Host address | `${facts.serverLan.serverIp}` |
        | DNS service address | `${facts.serverLan.dnsIp}` |
      ''}

      ## Firewall

      | Setting | Evaluated value |
      | --- | --- |
      | Enabled | ${yesNo facts.firewall.enable} |
      | Trusted interfaces | ${codeList facts.firewall.trustedInterfaces} |
      | Global TCP | ${codeList facts.firewall.tcpPorts} |
      | Global UDP | ${codeList facts.firewall.udpPorts} |
      | Global TCP ranges | ${portRanges facts.firewall.tcpPortRanges} |
      | Global UDP ranges | ${portRanges facts.firewall.udpPortRanges} |

      ${firewallInterfaceTable facts}

      ## Services

      **Server applications**

      ${bulletList facts.serverApps}

      **OCI containers**

      ${bulletList facts.containers}

      ## Packages

      | Package set | Count |
      | --- | ---: |
      | System packages | ${toString (builtins.length facts.systemPackages)} |
      | Home packages | ${toString (builtins.length facts.homePackages)} |

      Full evaluated package lists are in [Packages](../infrastructure/packages.md#${name}).

      ## Backups

      ${backupTable facts}

      ## Enabled scopes

      ${toString (builtins.length facts.enabledScopes)} scopes are enabled. Top-level scopes:

      ${bulletList facts.topLevelScopes}

      See [Semantic scopes](../configuration/scopes.md).
    '';

  hostMarkdown = lib.mapAttrs (name: _: systemMarkdown name) configurations;

  hostRunbookEnvironment =
    name: host:
    let
      inherit (host) config;
      primaryUser = config.dotfiles.users.primary;
      secretsBackup = config.services.restic.backups.secrets;
      value = fs: field: if fs == null then "" else fs.${field};
      rootFs = filesystem config "/";
      bootFs = filesystem config "/boot";
      homeFs = filesystem config "/home";
    in
    ''
      export HOST_NAME=${lib.escapeShellArg name}
      export SYSTEM=${lib.escapeShellArg host.pkgs.stdenv.hostPlatform.system}
      export PROFILE=${lib.escapeShellArg config.dotfiles.profile.name}
      export DOTFILES_REPO=${lib.escapeShellArg config.dotfiles.paths.repoPath}
      export PRIMARY_USER=${lib.escapeShellArg primaryUser.name}
      export PRIMARY_HOME=${lib.escapeShellArg "${primaryUser.homeRoot}/${primaryUser.name}"}
      export USER_SECRETS_DIR=${lib.escapeShellArg config.dotfiles.secretsDir}
      export SECRETS_REPOSITORY=${lib.escapeShellArg (toString secretsBackup.repository)}
      export SECRETS_PASSWORD_FILE=${lib.escapeShellArg (toString secretsBackup.passwordFile)}
      export SECRETS_RCLONE_CONFIG=${lib.escapeShellArg (toString secretsBackup.rcloneConfigFile)}
      export ROOT_DEVICE=${lib.escapeShellArg (value rootFs "device")}
      export ROOT_FS=${lib.escapeShellArg (value rootFs "fsType")}
      export BOOT_DEVICE=${lib.escapeShellArg (value bootFs "device")}
      export BOOT_FS=${lib.escapeShellArg (value bootFs "fsType")}
      export HOME_DEVICE=${lib.escapeShellArg (value homeFs "device")}
      export HOME_FS=${lib.escapeShellArg (value homeFs "fsType")}
    '';

  networkingMarkdown = ''
    # Networking

    | Host | Hostname | NetworkManager | Global DHCP | Nameservers | Managed profiles |
    | --- | --- | ---: | ---: | --- | --- |
    ${lib.concatMapStringsSep "\n" (
      name:
      let
        facts = hostFacts.${name};
      in
      "| `${name}` | `${facts.hostName}` | ${yesNo facts.networking.networkManager} | ${yesNo facts.networking.useDHCP} | ${cellList facts.networking.nameservers} | ${cellList facts.networking.profiles} |"
    ) hostNames}

    ${lib.concatMapStringsSep "\n" (
      name:
      let
        facts = hostFacts.${name};
      in
      lib.optionalString (facts.serverLan != null) ''
        ## `${name}` managed LAN

        | Setting | Evaluated value |
        | --- | --- |
        | Interface | `${facts.serverLan.interface}` |
        | Subnet | `${facts.serverLan.subnet}` |
        | Gateway | `${facts.serverLan.gateway}` |
        | Host address | `${facts.serverLan.serverIp}` |
        | DNS service address | `${facts.serverLan.dnsIp}` |
      ''
    ) hostNames}
  '';

  firewallMarkdown = ''
    # Firewall

    | Host | Enabled | Trusted interfaces | Global TCP | Global UDP | TCP ranges | UDP ranges |
    | --- | ---: | --- | --- | --- | --- | --- |
    ${lib.concatMapStringsSep "\n" (
      name:
      let
        facts = hostFacts.${name};
      in
      "| `${name}` | ${yesNo facts.firewall.enable} | ${cellList facts.firewall.trustedInterfaces} | ${codeList facts.firewall.tcpPorts} | ${codeList facts.firewall.udpPorts} | ${portRanges facts.firewall.tcpPortRanges} | ${portRanges facts.firewall.udpPortRanges} |"
    ) hostNames}

    ## Interface-specific rules

    ${lib.concatMapStringsSep "\n" (
      name:
      let
        facts = hostFacts.${name};
      in
      lib.optionalString (facts.firewallInterfaces != [ ]) ''
        ### `${name}`

        ${firewallInterfaceTable facts}
      ''
    ) hostNames}
  '';

  infrastructureStorageMarkdown = ''
    # Storage

    ## Filesystems

    | Host | Mount | Device | Filesystem | Options |
    | --- | --- | --- | --- | --- |
    ${lib.concatStringsSep "\n" (
      lib.concatMap (
        name:
        map (
          fs: "| `${name}` | `${fs.mountPoint}` | `${fs.device}` | `${fs.fsType}` | ${cellList fs.options} |"
        ) hostFacts.${name}.filesystems
      ) hostNames
    )}

    ${lib.concatMapStringsSep "\n" (
      name:
      let
        facts = hostFacts.${name};
      in
      lib.optionalString (facts.managedStorage != null) ''
        ## `${name}` managed storage

        | Setting | Evaluated value |
        | --- | --- |
        | Application data root | `${facts.managedStorage.appDataRoot}` |
        | Bulk data root | `${facts.managedStorage.dataRoot}` |
        | ZFS pool | `${facts.managedStorage.dataPool}` |
        | Snapshot interval | ${toString facts.managedStorage.snapshotIntervalMinutes} minutes |
        | Retention | ${toString facts.retention.hourly} hourly / ${toString facts.retention.daily} daily / ${toString facts.retention.weekly} weekly / ${toString facts.retention.monthly} monthly |
      ''
    ) hostNames}
  '';

  backupsMarkdown = ''
    # Backups

    ## Coverage

    | Host | Jobs | Hourly | Daily | Weekly | Monthly |
    | --- | ---: | ---: | ---: | ---: | ---: |
    ${lib.concatMapStringsSep "\n" (
      name:
      let
        facts = hostFacts.${name};
      in
      if facts.backupJobs == [ ] then
        "| `${name}` | 0 | — | — | — | — |"
      else
        "| `${name}` | ${toString (builtins.length facts.backupJobs)} | ${toString facts.retention.hourly} | ${toString facts.retention.daily} | ${toString facts.retention.weekly} | ${toString facts.retention.monthly} |"
    ) hostNames}

    ## Jobs

    | Host | Job | Repository | Schedule | Paths | Exclusions |
    | --- | --- | --- | --- | --- | --- |
    ${lib.concatMapStringsSep "\n" (
      name:
      let
        jobs = hostFacts.${name}.backupJobs;
      in
      if jobs == [ ] then
        "| `${name}` | _None_ | _None_ | _None_ | _None_ | _None_ |"
      else
        lib.concatMapStringsSep "\n" (
          backup:
          "| `${name}` | `${backup.name}` | `${backup.repository}` | ${optionalCode backup.schedule} | ${cellList backup.paths} | ${cellList backup.exclude} |"
        ) jobs
    ) hostNames}

    ## Maintenance

    | Host | Job | Repository | Schedule | Prune | Check |
    | --- | --- | --- | --- | --- | --- |
    ${lib.concatMapStringsSep "\n" (
      name:
      let
        jobs = hostFacts.${name}.maintenanceJobs;
      in
      if jobs == [ ] then
        "| `${name}` | _None_ | _None_ | _None_ | _None_ | _None_ |"
      else
        lib.concatMapStringsSep "\n" (
          job:
          "| `${name}` | `${job.name}` | `${job.repository}` | ${optionalCode job.schedule} | ${cellList job.pruneOpts} | ${cellList job.checkOpts} |"
        ) jobs
    ) hostNames}
  '';

  servicesMarkdown = ''
    # Services

    ${lib.concatMapStringsSep "\n" (
      name:
      let
        facts = hostFacts.${name};
      in
      ''
        ## `${name}`

        **Server applications**

        ${bulletList facts.serverApps}

        **OCI containers**

        ${bulletList facts.containers}
      ''
    ) hostNames}
  '';

  packagesMarkdown = ''
    # Packages

    | Host | System packages | Home packages |
    | --- | ---: | ---: |
    ${lib.concatMapStringsSep "\n" (
      name:
      let
        facts = hostFacts.${name};
      in
      "| `${name}` | ${toString (builtins.length facts.systemPackages)} | ${toString (builtins.length facts.homePackages)} |"
    ) hostNames}

    ${lib.concatMapStringsSep "\n" (
      name:
      let
        facts = hostFacts.${name};
      in
      ''
        ## `${name}`

        <details>
        <summary>System packages (${toString (builtins.length facts.systemPackages)})</summary>

        ${htmlPackageList facts.systemPackages}

        </details>

        <details>
        <summary>Home packages (${toString (builtins.length facts.homePackages)})</summary>

        ${htmlPackageList facts.homePackages}

        </details>
      ''
    ) hostNames}
  '';

  commonRunbookIndexMarkdown = ''
    # Common runbooks

    Procedures shared by multiple NixOS hosts.

    - [NixOS installer SSH](nixos-installer-ssh.md)
  '';

  hostRunbookIndexMarkdown =
    name:
    let
      serverRecovery = lib.optionalString (name == "nixos-server") ''
        - [Backup / application recovery](backup-recovery.md)
        - [Vault / ZFS recovery](vault-zfs-recovery.md)
      '';
    in
    ''
      # `${name}` runbooks

      Procedures for `${name}`.

      - [Installation guide](install.md)
      ${serverRecovery}
    '';

  summaryMarkdown = ''
    # Summary

    # Overview

    - [Fleet](overview/fleet.md)

    # Runbooks

    - [Common](runbooks/common/index.md)
      - [NixOS installer SSH](runbooks/common/nixos-installer-ssh.md)
    ${lib.concatMapStringsSep "\n" (
      name:
      let
        serverRecovery =
          lib.optionalString (name == "nixos-server")
            "\n  - [Backup / application recovery](runbooks/nixos-server/backup-recovery.md)\n  - [Vault / ZFS recovery](runbooks/nixos-server/vault-zfs-recovery.md)";
      in
      "- [`${name}`](runbooks/${name}/index.md)\n  - [Installation guide](runbooks/${name}/install.md)${serverRecovery}"
    ) hostNames}

    # Systems

    ${lib.concatMapStringsSep "\n" (name: "- [`${name}`](systems/${name}.md)") hostNames}

    # Infrastructure

    - [Networking](infrastructure/networking.md)
      - [Firewall](infrastructure/firewall.md)
    - [Storage](infrastructure/storage.md)
    - [Backups](infrastructure/backups.md)
    - [Services](infrastructure/services.md)
    - [Packages](infrastructure/packages.md)

    # Configuration

    - [Semantic scopes](configuration/scopes.md)
    - [dotfiles options](configuration/options.md)
  '';

  runbookEnvironment = ''
    ${hostRunbookEnvironment "nixos-server" server}
    export APP_DATA_ROOT=${lib.escapeShellArg storage.appData.root}
    export VAULT_ROOT=${lib.escapeShellArg storage.dataRoot.path}
    export VAULT_POOL=${lib.escapeShellArg storage.dataRoot.poolName}
    export VAULT_DATASET=${lib.escapeShellArg "${storage.dataRoot.poolName}/data"}
    export SERVER_SECRETS_DIR=${lib.escapeShellArg serverConfig.dotfiles.server.secretsDir}
    export SERVER_IP=${lib.escapeShellArg lan.serverIp}
    export IMMICH_MEDIA_ROOT=${lib.escapeShellArg immichMediaRoot}
    export IMMICH_BACKUP_ROOT=${lib.escapeShellArg "${immichMediaRoot}/backups"}
    export PAPERLESS_DATA_ROOT=${lib.escapeShellArg paperlessDataRoot}
    export PAPERLESS_MEDIA_ROOT=${lib.escapeShellArg paperlessMediaRoot}
    export PAPERLESS_CONSUME_ROOT=${lib.escapeShellArg paperlessConsumeRoot}
    export PAPERLESS_BACKUP_ROOT=${lib.escapeShellArg paperlessBackupRoot}
  '';

  generatedFiles = {
    "SUMMARY.md" = summaryMarkdown;
    "configuration/scopes.md" = semanticScopesMarkdown;
    "generated/server-env.sh" = runbookEnvironment;
    "infrastructure/backups.md" = backupsMarkdown;
    "infrastructure/firewall.md" = firewallMarkdown;
    "infrastructure/networking.md" = networkingMarkdown;
    "infrastructure/packages.md" = packagesMarkdown;
    "infrastructure/services.md" = servicesMarkdown;
    "infrastructure/storage.md" = infrastructureStorageMarkdown;
    "overview/fleet.md" = fleetMarkdown;
    "runbooks/common/index.md" = commonRunbookIndexMarkdown;
  }
  // lib.mapAttrs' (name: markdown: lib.nameValuePair "systems/${name}.md" markdown) hostMarkdown
  // lib.genAttrs' hostNames (
    name: lib.nameValuePair "runbooks/${name}/index.md" (hostRunbookIndexMarkdown name)
  )
  // lib.mapAttrs' (
    name: host: lib.nameValuePair "generated/hosts/${name}.sh" (hostRunbookEnvironment name host)
  ) configurations;

  generatedFileSources = lib.mapAttrs (
    path: contents: builtins.toFile "dotfiles-${lib.replaceStrings [ "/" ] [ "-" ] path}" contents
  ) generatedFiles;

  missingInstallRunbooks = lib.filter (
    name: !(builtins.pathExists "${source}/docs/manual/src/runbooks/${name}/install.md")
  ) hostNames;

  docsSource =
    assert lib.assertMsg (missingInstallRunbooks == [ ]) ''
      Missing install/recovery runbook(s) for: ${lib.concatStringsSep ", " missingInstallRunbooks}
      Add docs/manual/src/runbooks/<configuration>/install.md for every nixosConfigurations entry.
    '';
    pkgs.runCommand "dotfiles-docs-source"
      {
        nativeBuildInputs = [ pkgs.nixdoc ];
      }
      ''
        set -euo pipefail
        cp -R ${source}/docs/manual/. "$out"
        chmod -R u+w "$out/src"
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (path: file: ''
            install -D -m 0644 ${file} "$out/src/${path}"
          '') generatedFileSources
        )}

        {
          echo '# dotfiles option reference'
          echo
          sed -E \
            -e "s#${source}/##g" \
            -e 's#\[([^]]+)\]\(file://[^)]*\)#`\1`#g' \
            -e 's|^## (.*) \{#([^}]+)\}$|<h2 id="\2">\1</h2>|' \
            -e '/^<h2 id=/ s/\\\././g' \
            ${optionDocsCommonMark}
        } > "$out/src/configuration/options.md"

        while IFS= read -r -d "" file; do
          grep -q '/\*\*' "$file" || continue
          relative="''${file#${source}/}"
          anchor="$(printf '%s' "$relative" | tr '/.' '--')"
          rendered="$(nixdoc --file "$file" --category "" --description "" --prefix "" --anchor-prefix "$anchor-")"
          [ -n "$(printf '%s' "$rendered" | tr -d '[:space:]')" ] || continue
          printf '\n## `%s`\n\n' "$relative" >> "$out/src/configuration/scopes.md"
          printf '%s\n' "$rendered" \
            | sed -E 's/^(#{1,5})([[:space:]])/#\1\2/' \
            >> "$out/src/configuration/scopes.md"
        done < <(
          find ${source}/modules ${source}/lib -type f -name '*.nix' -print0 | sort -z
        )

      '';

  book =
    pkgs.runCommand "dotfiles-docs"
      {
        nativeBuildInputs = [ pkgs.mdbook ];
      }
      ''
        set -euo pipefail
        mdbook build ${docsSource} --dest-dir "$out"
      '';
in
{
  inherit book docsSource;
}
