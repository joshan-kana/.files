{
  configurations,
  lib,
  pkgs,
  semanticScopeOptions,
  source,
}:

let
  server = configurations.nixos-server;
  serverConfig = server.config;

  allScopeOptions = semanticScopeOptions.nixdOptions configurations;
  serverOptions = semanticScopeOptions.nixdHostOptions configurations server;
  projectOptions = {
    dotfiles =
      (builtins.removeAttrs serverOptions.dotfiles [
        "scopes"
        "resolvedScopes"
      ])
      // {
        scopes = allScopeOptions.dotfiles.scopes;
      };
  };

  optionDocs = pkgs.nixosOptionsDoc {
    options = projectOptions;
    documentType = "none";
    variablelistId = "dotfiles-options";
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

  hostNames = builtins.attrNames configurations;

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
      backupJobs = lib.mapAttrsToList (backupName: backup: {
        name = backupName;
        repository = toString backup.repository;
        paths = backup.paths or [ ];
        exclude = backup.exclude or [ ];
        schedule = backup.timerConfig.OnCalendar or null;
        prune = backup.pruneOpts or [ ];
      }) config.services.restic.backups;
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
      container = config.boot.isContainer or false;
      inherit
        filesystems
        systemPackages
        homePackages
        backupJobs
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
  primary = serverConfig.dotfiles.users.primary;
  primaryHome = "${primary.homeRoot}/${primary.name}";
  immichMediaRoot = serverConfig.services.immich.mediaLocation;
  paperlessDataRoot = serverConfig.services.paperless.dataDir;
  paperlessMediaRoot = serverConfig.services.paperless.mediaDir;
  paperlessConsumeRoot = serverConfig.services.paperless.consumptionDir;
  paperlessBackupRoot = serverConfig.services.postgresqlBackup.location;

  referenceModel = {
    hosts = hostFacts;
    server = {
      appDataRoot = storage.appData.root;
      dataRoot = storage.dataRoot.path;
      dataPool = storage.dataRoot.poolName;
      snapshotIntervalMinutes = storage.snapshots.intervalMinutes;
      secretsDir = serverConfig.dotfiles.server.secretsDir;
      repoPath = serverConfig.dotfiles.paths.repoPath;
      primaryUser = primary.name;
      inherit primaryHome;
      userSecretsDir = serverConfig.dotfiles.secretsDir;
      applications = {
        immich = {
          mediaRoot = immichMediaRoot;
          backupRoot = "${immichMediaRoot}/backups";
        };
        paperless = {
          dataRoot = paperlessDataRoot;
          mediaRoot = paperlessMediaRoot;
          consumeRoot = paperlessConsumeRoot;
          backupRoot = paperlessBackupRoot;
        };
      };
    };
  };

  referenceJson = pkgs.writeText "dotfiles-reference.json" (builtins.toJSON referenceModel);

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

    | Host | Platform | Profile | Container | Backup jobs | Server apps | System packages | Home packages |
    | --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
    ${lib.concatMapStringsSep "\n" (
      name:
      let
        facts = hostFacts.${name};
      in
      "| `${name}` | `${facts.system}` | `${facts.profile}` | ${yesNo facts.container} | ${toString (builtins.length facts.backupJobs)} | ${toString (builtins.length facts.serverApps)} | ${toString (builtins.length facts.systemPackages)} | ${toString (builtins.length facts.homePackages)} |"
    ) hostNames}
  '';

  scopeMatrixMarkdown = ''
    # Scope matrix

    ${scopeTableHeader}
    ${lib.concatStringsSep "\n" scopeTableRows}
  '';

  semanticScopesMarkdown = ''
    # Semantic scopes
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
      | Container | ${yesNo facts.container} |

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

      See the fleet-wide [scope matrix](../overview/scope-matrix.md).
    '';

  hostMarkdown = lib.mapAttrs (name: _: systemMarkdown name) configurations;
  hostSources = lib.mapAttrs (
    name: markdown: pkgs.writeText "dotfiles-host-${name}.md" markdown
  ) hostMarkdown;

  hostRunbookEnvironment =
    name: host:
    let
      inherit (host) config;
      primaryUser = config.dotfiles.users.primary;
      value = fs: field: if fs == null then "" else fs.${field};
      rootFs = filesystem config "/";
      bootFs = filesystem config "/boot";
      homeFs = filesystem config "/home";
    in
    ''
      HOST_NAME=${lib.escapeShellArg name}
      SYSTEM=${lib.escapeShellArg host.pkgs.stdenv.hostPlatform.system}
      PROFILE=${lib.escapeShellArg config.dotfiles.profile.name}
      DOTFILES_REPO=${lib.escapeShellArg config.dotfiles.paths.repoPath}
      PRIMARY_USER=${lib.escapeShellArg primaryUser.name}
      PRIMARY_HOME=${lib.escapeShellArg "${primaryUser.homeRoot}/${primaryUser.name}"}
      ROOT_DEVICE=${lib.escapeShellArg (value rootFs "device")}
      ROOT_FS=${lib.escapeShellArg (value rootFs "fsType")}
      BOOT_DEVICE=${lib.escapeShellArg (value bootFs "device")}
      BOOT_FS=${lib.escapeShellArg (value bootFs "fsType")}
      HOME_DEVICE=${lib.escapeShellArg (value homeFs "device")}
      HOME_FS=${lib.escapeShellArg (value homeFs "fsType")}
    '';

  hostEnvironmentSources = lib.mapAttrs (
    name: host: pkgs.writeText "dotfiles-host-${name}-env.sh" (hostRunbookEnvironment name host)
  ) configurations;

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
    ${lib.concatMapStringsSep "\n" (
      name:
      lib.concatMapStringsSep "\n" (
        fs: "| `${name}` | `${fs.mountPoint}` | `${fs.device}` | `${fs.fsType}` | ${cellList fs.options} |"
      ) hostFacts.${name}.filesystems
    ) hostNames}

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

  fleetSource = pkgs.writeText "dotfiles-fleet.md" fleetMarkdown;
  scopeMatrixSource = pkgs.writeText "dotfiles-scope-matrix.md" scopeMatrixMarkdown;
  semanticScopesSource = pkgs.writeText "dotfiles-semantic-scopes.md" semanticScopesMarkdown;
  networkingSource = pkgs.writeText "dotfiles-networking.md" networkingMarkdown;
  firewallSource = pkgs.writeText "dotfiles-firewall.md" firewallMarkdown;
  infrastructureStorageSource = pkgs.writeText "dotfiles-storage.md" infrastructureStorageMarkdown;
  infrastructureBackupsSource = pkgs.writeText "dotfiles-backups.md" backupsMarkdown;
  servicesSource = pkgs.writeText "dotfiles-services.md" servicesMarkdown;
  packagesSource = pkgs.writeText "dotfiles-packages.md" packagesMarkdown;

  summaryMarkdown = ''
    # Summary

    # Overview

    - [Fleet](overview/fleet.md)
    - [Scope matrix](overview/scope-matrix.md)

    # Systems

    ${lib.concatMapStringsSep "\n" (
      name: "- [`${name}`](systems/${name}.md)\n  - [Install or recover](runbooks/install/${name}.md)"
    ) hostNames}

    # Infrastructure

    - [Networking](infrastructure/networking.md)
      - [Firewall](infrastructure/firewall.md)
    - [Storage](infrastructure/storage.md)
    - [Backups](infrastructure/backups.md)
    - [Services](infrastructure/services.md)
    - [Packages](infrastructure/packages.md)

    # Operations

    - [Backup restore](operations/backup-restore.md)
    - [Vault / ZFS recovery](operations/vault-recovery.md)

    # Configuration

    - [Semantic scopes](configuration/scopes.md)
    - [dotfiles options](configuration/options.md)
  '';

  summarySource = pkgs.writeText "dotfiles-summary.md" summaryMarkdown;

  runbookEnvironment = ''
    ${hostRunbookEnvironment "nixos-server" server}
    APP_DATA_ROOT=${lib.escapeShellArg storage.appData.root}
    VAULT_ROOT=${lib.escapeShellArg storage.dataRoot.path}
    VAULT_POOL=${lib.escapeShellArg storage.dataRoot.poolName}
    VAULT_DATASET=${lib.escapeShellArg "${storage.dataRoot.poolName}/data"}
    SERVER_SECRETS_DIR=${lib.escapeShellArg serverConfig.dotfiles.server.secretsDir}
    USER_SECRETS_DIR=${lib.escapeShellArg serverConfig.dotfiles.secretsDir}
    DOTFILES_REPO=${lib.escapeShellArg serverConfig.dotfiles.paths.repoPath}
    PRIMARY_USER=${lib.escapeShellArg primary.name}
    PRIMARY_HOME=${lib.escapeShellArg primaryHome}
    SERVER_IP=${lib.escapeShellArg lan.serverIp}
    IMMICH_MEDIA_ROOT=${lib.escapeShellArg immichMediaRoot}
    IMMICH_BACKUP_ROOT=${lib.escapeShellArg "${immichMediaRoot}/backups"}
    PAPERLESS_DATA_ROOT=${lib.escapeShellArg paperlessDataRoot}
    PAPERLESS_MEDIA_ROOT=${lib.escapeShellArg paperlessMediaRoot}
    PAPERLESS_CONSUME_ROOT=${lib.escapeShellArg paperlessConsumeRoot}
    PAPERLESS_BACKUP_ROOT=${lib.escapeShellArg paperlessBackupRoot}
  '';

  runbookEnvironmentSource = pkgs.writeText "dotfiles-server-env.sh" runbookEnvironment;

  docsSource =
    pkgs.runCommand "dotfiles-docs-source"
      {
        nativeBuildInputs = [
          pkgs.coreutils
          pkgs.findutils
          pkgs.gnused
          pkgs.nixdoc
        ];
      }
      ''
        set -euo pipefail
        cp -R ${source}/docs/manual/. "$out"
        chmod -R u+w "$out"
        mkdir -p \
          "$out/src/configuration" \
          "$out/src/generated/hosts" \
          "$out/src/infrastructure" \
          "$out/src/overview" \
          "$out/src/systems" \
          "$out/data"

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

        install -m 0644 ${summarySource} "$out/src/SUMMARY.md"
        install -m 0644 ${fleetSource} "$out/src/overview/fleet.md"
        install -m 0644 ${scopeMatrixSource} "$out/src/overview/scope-matrix.md"
        install -m 0644 ${semanticScopesSource} "$out/src/configuration/scopes.md"
        install -m 0644 ${networkingSource} "$out/src/infrastructure/networking.md"
        install -m 0644 ${firewallSource} "$out/src/infrastructure/firewall.md"
        install -m 0644 ${infrastructureStorageSource} "$out/src/infrastructure/storage.md"
        install -m 0644 ${infrastructureBackupsSource} "$out/src/infrastructure/backups.md"
        install -m 0644 ${servicesSource} "$out/src/infrastructure/services.md"
        install -m 0644 ${packagesSource} "$out/src/infrastructure/packages.md"
        ${lib.concatMapStringsSep "\n" (name: ''
          install -m 0644 ${hostSources.${name}} "$out/src/systems/${name}.md"
          install -m 0644 ${hostEnvironmentSources.${name}} "$out/src/generated/hosts/${name}.sh"
        '') hostNames}
        install -m 0644 ${runbookEnvironmentSource} "$out/src/generated/server-env.sh"
        chmod u+w "$out/src/configuration/scopes.md"

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

        cp ${optionDocs.optionsJSON}/share/doc/nixos/options.json "$out/data/options.json"
        cp ${referenceJson} "$out/data/reference.json"

        for required in \
          src/configuration/options.md \
          src/configuration/scopes.md \
          src/overview/fleet.md \
          src/overview/scope-matrix.md \
          src/infrastructure/networking.md \
          src/infrastructure/firewall.md \
          src/infrastructure/storage.md \
          src/infrastructure/backups.md \
          src/infrastructure/services.md \
          src/infrastructure/packages.md \
          src/generated/server-env.sh \
          data/options.json \
          data/reference.json; do
          test -s "$out/$required"
        done

        ${lib.concatMapStringsSep "\n" (name: ''
          test -s "$out/src/systems/${name}.md"
          test -s "$out/src/generated/hosts/${name}.sh"
          test -s "$out/src/runbooks/install/${name}.md"
        '') hostNames}
      '';

  book =
    pkgs.runCommand "dotfiles-docs"
      {
        nativeBuildInputs = [ pkgs.mdbook ];
      }
      ''
        set -euo pipefail
        mdbook build ${docsSource} --dest-dir "$out"
        mkdir -p "$out/data"
        cp -R ${docsSource}/data/. "$out/data/"
      '';
in
{
  inherit book docsSource referenceModel;
}
