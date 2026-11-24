{
  configurations,
  darwinConfigurations ? { },
  lib,
  pkgs,
  semanticScopeOptions,
  source,
}:

let
  # Documentation pipeline:
  # 1. Evaluate host configuration and semantic scopes into documentation facts.
  # 2. Render generated Markdown pages and runbook environment snippets.
  # 3. Overlay generated files onto the handwritten docs/manual source tree.
  # 4. Render the assembled Markdown tree with mdBook.
  allConfigurations = configurations // darwinConfigurations;
  hostNames = builtins.attrNames allConfigurations;
  nixosHostNames = builtins.attrNames configurations;

  # Nix option reference
  #
  # Merge host-specific dotfiles options, but use the shared scope option tree so
  # the reference describes the complete reusable interface rather than one
  # host's resolved scope state.
  allScopeOptions = semanticScopeOptions.nixdOptions allConfigurations;
  hostOptionTrees = map (
    name: semanticScopeOptions.nixdHostOptions allConfigurations allConfigurations.${name}
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
    transformOptions =
      option:
      option
      // {
        # Declaration paths are display text here, not build inputs. Make them
        # repo-relative and discard their original store-string context before
        # nixosOptionsDoc turns them into links.
        declarations = map (
          declaration:
          builtins.unsafeDiscardStringContext (lib.removePrefix "${source}/" (toString declaration))
        ) option.declarations;
      };
  };
  optionDocsCommonMark = optionDocs.optionsCommonMark.overrideAttrs {
    extraArgs = [
      "--anchor-style"
      "legacy"
      "--anchor-prefix"
      "opt-"
    ];
  };

  # Semantic scope inventory
  #
  # A semantic scope node is an attrset with an enable option. Flatten the
  # resolved tree so generated docs can compare scope state across hosts.
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
  ) allConfigurations;
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

  # Markdown formatting helpers
  filesystemAt = config: mountPoint: lib.attrByPath [ mountPoint ] null config.fileSystems;
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
  # Package lists live inside raw HTML <details> blocks, so render the list
  # itself as HTML rather than relying on Markdown parsing inside those blocks.
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

  # Evaluated host facts
  #
  # Keep page renderers independent from native platform configuration shapes.
  # This is the documentation-facing projection of each evaluated host.
  hostFacts = lib.mapAttrs (
    name: host:
    let
      inherit (host) config;
      primaryUser = config.dotfiles.users.primary;
      inherit (host.pkgs.stdenv.hostPlatform) isLinux;
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
      # Restic maintenance uses the same NixOS backup attrset, but has no
      # backup paths and only prune/check work. Keep it out of backup coverage.
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
      inherit isLinux systemPackages homePackages;
      serverApps = enabledServerApps config;
      enabledScopes = enabledScopeNames name;
      topLevelScopes = topLevelScopeNames name;
    }
    // lib.optionalAttrs isLinux {
      inherit
        filesystems
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
            snapshotRetention = config.services.sanoid.templates.vault;
          }
        else
          null;
    }
    // lib.optionalAttrs (!isLinux) {
      launchAgents = enabledLaunchAgentLabels config;
      secretsBackup =
        if lib.attrByPath [ "backups" "secrets" "enable" ] false config.dotfiles.resolvedScopes then
          {
            inherit (config.dotfiles.backups.secrets) repository;
            path = config.dotfiles.secretsDir;
          }
        else
          null;
    }
  ) allConfigurations;

  enabledLaunchAgentLabels =
    config:
    map (agent: agent.config.Label) (
      builtins.attrValues (
        lib.filterAttrs (
          _: agent: agent.enable && agent.config ? Label
        ) config.home-manager.users.${config.dotfiles.users.primary.name}.launchd.agents
      )
    );

  # Reusable Markdown fragments
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

  darwinBackupMarkdown =
    facts:
    if facts.secretsBackup == null then
      "_Secrets backup is disabled._"
    else
      ''
        | Repository | Protected path |
        | --- | --- |
        | `${facts.secretsBackup.repository}` | `${facts.secretsBackup.path}` |

        Managed launch agents are listed on the host's system page.
      '';

  # Generated reference pages
  fleetMarkdown = ''
    # Fleet

    | Host | Platform | NixOS Restic jobs | Server apps | System packages | Home packages |
    | --- | --- | ---: | ---: | ---: | ---: |
    ${lib.concatMapStringsSep "\n" (
      name:
      let
        facts = hostFacts.${name};
      in
      "| `${name}` | `${facts.system}` | ${
        if facts.isLinux then toString (builtins.length facts.backupJobs) else "—"
      } | ${toString (builtins.length facts.serverApps)} | ${toString (builtins.length facts.systemPackages)} | ${toString (builtins.length facts.homePackages)} |"
    ) hostNames}

    Backup coverage on each platform is described in [Backups](../infrastructure/backups.md).
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

      ${lib.optionalString facts.isLinux ''
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
      ''}

      ${lib.optionalString (!facts.isLinux) ''
        ## Managed launch agents

        ${bulletList facts.launchAgents}
      ''}

      ## Packages

      | Package set | Count |
      | --- | ---: |
      | System packages | ${toString (builtins.length facts.systemPackages)} |
      | Home packages | ${toString (builtins.length facts.homePackages)} |

      Full evaluated package lists are in [Packages](../infrastructure/packages.md#${name}).

      ## Backups

      ${if facts.isLinux then backupTable facts else darwinBackupMarkdown facts}

      ## Enabled scopes

      ${toString (builtins.length facts.enabledScopes)} scopes are enabled. Top-level scopes:

      ${bulletList facts.topLevelScopes}

      See [Semantic scopes](../configuration/scopes.md).
    '';

  # Runbook environment snippets
  #
  # Installation/recovery guides include these generated shell exports so paths
  # and backup capability always match the evaluated target host.
  hostRunbookEnvironment =
    name: host:
    let
      inherit (host) config;
      primaryUser = config.dotfiles.users.primary;
      secretsBackup = lib.attrByPath [ "secrets" ] null config.services.restic.backups;
      backupValue = field: if secretsBackup == null then "" else toString secretsBackup.${field};
      filesystemValue = fs: field: if fs == null then "" else fs.${field};
      rootFs = filesystemAt config "/";
      bootFs = filesystemAt config "/boot";
      homeFs = filesystemAt config "/home";
    in
    ''
      export HOST_NAME=${lib.escapeShellArg name}
      export SYSTEM=${lib.escapeShellArg host.pkgs.stdenv.hostPlatform.system}
      export PROFILE=${lib.escapeShellArg config.dotfiles.profile.name}
      export DOTFILES_REPO=${lib.escapeShellArg config.dotfiles.paths.repoPath}
      export PRIMARY_USER=${lib.escapeShellArg primaryUser.name}
      export PRIMARY_HOME=${lib.escapeShellArg "${primaryUser.homeRoot}/${primaryUser.name}"}
      export USER_SECRETS_DIR=${lib.escapeShellArg config.dotfiles.secretsDir}
      export SECRETS_BACKUP_ENABLED=${
        lib.escapeShellArg (if secretsBackup == null then "false" else "true")
      }
      export SECRETS_REPOSITORY=${lib.escapeShellArg (backupValue "repository")}
      export SECRETS_PASSWORD_FILE=${lib.escapeShellArg (backupValue "passwordFile")}
      export SECRETS_RCLONE_CONFIG=${lib.escapeShellArg (backupValue "rcloneConfigFile")}
      export ROOT_DEVICE=${lib.escapeShellArg (filesystemValue rootFs "device")}
      export ROOT_FS=${lib.escapeShellArg (filesystemValue rootFs "fsType")}
      export BOOT_DEVICE=${lib.escapeShellArg (filesystemValue bootFs "device")}
      export BOOT_FS=${lib.escapeShellArg (filesystemValue bootFs "fsType")}
      export HOME_DEVICE=${lib.escapeShellArg (filesystemValue homeFs "device")}
      export HOME_FS=${lib.escapeShellArg (filesystemValue homeFs "fsType")}
    '';

  # Cross-host infrastructure pages
  networkingMarkdown = ''
    # Networking

    These tables describe the evaluated NixOS configuration.

    | Host | Hostname | NetworkManager | Global DHCP | Nameservers | Managed profiles |
    | --- | --- | ---: | ---: | --- | --- |
    ${lib.concatMapStringsSep "\n" (
      name:
      let
        facts = hostFacts.${name};
      in
      "| `${name}` | `${facts.hostName}` | ${yesNo facts.networking.networkManager} | ${yesNo facts.networking.useDHCP} | ${cellList facts.networking.nameservers} | ${cellList facts.networking.profiles} |"
    ) nixosHostNames}

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
    ) nixosHostNames}
  '';

  firewallMarkdown = ''
    # Firewall

    These tables describe the evaluated NixOS configuration.

    | Host | Enabled | Trusted interfaces | Global TCP | Global UDP | TCP ranges | UDP ranges |
    | --- | ---: | --- | --- | --- | --- | --- |
    ${lib.concatMapStringsSep "\n" (
      name:
      let
        facts = hostFacts.${name};
      in
      "| `${name}` | ${yesNo facts.firewall.enable} | ${cellList facts.firewall.trustedInterfaces} | ${codeList facts.firewall.tcpPorts} | ${codeList facts.firewall.udpPorts} | ${portRanges facts.firewall.tcpPortRanges} | ${portRanges facts.firewall.udpPortRanges} |"
    ) nixosHostNames}

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
    ) nixosHostNames}
  '';

  infrastructureStorageMarkdown = ''
    # Storage

    These tables describe the evaluated NixOS configuration.

    ## Filesystems

    | Host | Mount | Device | Filesystem | Options |
    | --- | --- | --- | --- | --- |
    ${lib.concatStringsSep "\n" (
      lib.concatMap (
        name:
        map (
          fs: "| `${name}` | `${fs.mountPoint}` | `${fs.device}` | `${fs.fsType}` | ${cellList fs.options} |"
        ) hostFacts.${name}.filesystems
      ) nixosHostNames
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
        | Vault snapshot retention | ${toString facts.managedStorage.snapshotRetention.hourly} hourly / ${toString facts.managedStorage.snapshotRetention.daily} daily / ${toString facts.managedStorage.snapshotRetention.weekly} weekly / ${toString facts.managedStorage.snapshotRetention.monthly} monthly |
      ''
    ) nixosHostNames}
  '';

  backupsMarkdown = ''
    # Backups

    ## NixOS coverage

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
    ) nixosHostNames}

    ## NixOS jobs

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
    ) nixosHostNames}

    ## NixOS maintenance

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
    ) nixosHostNames}
    ${lib.optionalString (darwinConfigurations != { }) ''
      ## Darwin secrets backup

      ${lib.concatMapStringsSep "\n" (name: ''
        ### `${name}`

        ${darwinBackupMarkdown hostFacts.${name}}
      '') (builtins.attrNames darwinConfigurations)}
    ''}
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

  # Runbook titles come from the authored pages; installation comes first.
  runbookPages =
    name:
    let
      directory = "${source}/docs/manual/src/runbooks/${name}";
      files =
        if builtins.pathExists directory then builtins.attrNames (builtins.readDir directory) else [ ];
      pages = lib.filter (file: lib.hasSuffix ".md" file && file != "index.md") files;
    in
    map (file: {
      inherit file;
      title =
        if file == "install.md" then
          "Installation guide"
        else
          lib.removePrefix "# " (
            builtins.head (lib.splitString "\n" (builtins.readFile "${directory}/${file}"))
          );
    }) (lib.optional (builtins.elem "install.md" pages) "install.md" ++ lib.remove "install.md" pages);

  runbookIndexMarkdown = name: ''
    # ${if name == "common" then "Common runbooks" else "`${name}` runbooks"}

    ${lib.concatMapStringsSep "\n" (page: "- [${page.title}](${page.file})") (runbookPages name)}
  '';

  # mdBook navigation
  #
  # Host entries come from the configuration outputs and authored runbooks.
  summaryMarkdown = ''
    # Summary

    # Overview

    - [Fleet](overview/fleet.md)

    # Runbooks

    ${lib.concatMapStringsSep "\n" (
      name:
      "- [${if name == "common" then "Common" else "`${name}`"}](runbooks/${name}/index.md)"
      + lib.concatMapStrings (page: "\n  - [${page.title}](runbooks/${name}/${page.file})") (
        runbookPages name
      )
    ) ([ "common" ] ++ hostNames)}

    # Systems

    ${lib.concatMapStringsSep "\n" (name: "- [`${name}`](systems/${name}.md)") hostNames}

    # Infrastructure

    - [Networking](infrastructure/networking.md)
      - [Firewall](infrastructure/firewall.md)
    - [Storage](infrastructure/storage.md)
    - [Backups](infrastructure/backups.md)
    - [Packages](infrastructure/packages.md)

    # Configuration

    - [Semantic scopes](configuration/scopes.md)
    - [dotfiles options](configuration/options.md)
  '';

  darwinRunbookEnvironment =
    name: host:
    let
      inherit (host) config;
      primary = config.dotfiles.users.primary;
      secretBackup = config.dotfiles.backups.secrets;
      enabledAgentLabels = enabledLaunchAgentLabels config;
    in
    ''
      export HOST_NAME=${lib.escapeShellArg name}
      export SYSTEM=${lib.escapeShellArg host.pkgs.stdenv.hostPlatform.system}
      export PROFILE=${lib.escapeShellArg config.dotfiles.profile.name}
      export DOTFILES_REPO=${lib.escapeShellArg config.dotfiles.paths.repoPath}
      export PRIMARY_USER=${lib.escapeShellArg primary.name}
      export PRIMARY_HOME=${lib.escapeShellArg "${primary.homeRoot}/${primary.name}"}
      export USER_SECRETS_DIR=${lib.escapeShellArg config.dotfiles.secretsDir}
      export SECRETS_BACKUP_ENABLED=${
        lib.escapeShellArg (
          lib.boolToString (
            lib.attrByPath [ "backups" "secrets" "enable" ] false config.dotfiles.resolvedScopes
          )
        )
      }
      export SECRETS_REPOSITORY=${lib.escapeShellArg secretBackup.repository}
      export SECRETS_RCLONE_CONFIG=${lib.escapeShellArg secretBackup.rcloneConfigFile}
      export SECRETS_PASSWORD_FILE=${lib.escapeShellArg secretBackup.passwordFile}
      MANAGED_LAUNCHD_LABELS=(
      ${lib.concatMapStringsSep "\n" (label: "  ${lib.escapeShellArg label}") enabledAgentLabels}
      )
    '';

  serverRunbookEnvironment =
    config:
    let
      storage = config.dotfiles.server.storage;
      immichMediaRoot = config.services.immich.mediaLocation;
    in
    ''
      export APP_DATA_ROOT=${lib.escapeShellArg storage.appData.root}
      export VAULT_ROOT=${lib.escapeShellArg storage.dataRoot.path}
      export VAULT_POOL=${lib.escapeShellArg storage.dataRoot.poolName}
      export VAULT_DATASET=${lib.escapeShellArg "${storage.dataRoot.poolName}/data"}
      export SERVER_SECRETS_DIR=${lib.escapeShellArg config.dotfiles.server.secretsDir}
      export SERVER_IP=${lib.escapeShellArg config.dotfiles.server.lan.serverIp}
    ''
    + lib.optionalString config.services.immich.enable ''
      export IMMICH_MEDIA_ROOT=${lib.escapeShellArg immichMediaRoot}
      export IMMICH_BACKUP_ROOT=${lib.escapeShellArg "${immichMediaRoot}/backups"}
    ''
    + lib.optionalString config.services.paperless.enable ''
      export PAPERLESS_DATA_ROOT=${lib.escapeShellArg config.services.paperless.dataDir}
      export PAPERLESS_MEDIA_ROOT=${lib.escapeShellArg config.services.paperless.mediaDir}
      export PAPERLESS_CONSUME_ROOT=${lib.escapeShellArg config.services.paperless.consumptionDir}
      export PAPERLESS_BACKUP_ROOT=${lib.escapeShellArg config.services.postgresqlBackup.location}
    '';

  # Generated file assembly
  systemFiles = lib.mapAttrs' (
    name: _: lib.nameValuePair "systems/${name}.md" (systemMarkdown name)
  ) allConfigurations;
  hostRunbookIndexFiles = lib.genAttrs' ([ "common" ] ++ hostNames) (
    name: lib.nameValuePair "runbooks/${name}/index.md" (runbookIndexMarkdown name)
  );
  hostEnvironmentFiles = lib.mapAttrs' (
    name: host:
    lib.nameValuePair "generated/hosts/${name}.sh" (
      hostRunbookEnvironment name host
      + lib.optionalString (lib.hasAttrByPath [ "dotfiles" "server" "storage" ] host.config) (
        serverRunbookEnvironment host.config
      )
    )
  ) configurations;
  darwinHostEnvironmentFiles = lib.mapAttrs' (
    name: host: lib.nameValuePair "generated/hosts/${name}.sh" (darwinRunbookEnvironment name host)
  ) darwinConfigurations;

  generatedFiles = {
    "SUMMARY.md" = summaryMarkdown;
    "configuration/scopes.md" = semanticScopesMarkdown;
    "infrastructure/backups.md" = backupsMarkdown;
    "infrastructure/firewall.md" = firewallMarkdown;
    "infrastructure/networking.md" = networkingMarkdown;
    "infrastructure/packages.md" = packagesMarkdown;
    "infrastructure/storage.md" = infrastructureStorageMarkdown;
    "overview/fleet.md" = fleetMarkdown;
  }
  // systemFiles
  // hostRunbookIndexFiles
  // hostEnvironmentFiles
  // darwinHostEnvironmentFiles;

  # Materialize generated strings as store files so docsSource can overlay them
  # onto the handwritten source tree with normal file operations.
  generatedStoreFiles = lib.mapAttrs (
    path: contents: builtins.toFile "dotfiles-${lib.replaceStrings [ "/" ] [ "-" ] path}" contents
  ) generatedFiles;

  # Every configured host must have one human-authored installation procedure.
  missingInstallRunbooks = lib.filter (
    name: !(builtins.pathExists "${source}/docs/manual/src/runbooks/${name}/install.md")
  ) hostNames;

  # Assemble the complete Markdown source tree.
  docsSource =
    assert lib.assertMsg (missingInstallRunbooks == [ ]) ''
      Missing install/recovery runbook(s) for: ${lib.concatStringsSep ", " missingInstallRunbooks}
      Add docs/manual/src/runbooks/<configuration>/install.md for every configured host.
    '';
    pkgs.runCommand "dotfiles-docs-source"
      {
        nativeBuildInputs = [ pkgs.nixdoc ];
      }
      ''
        set -euo pipefail

        # Start with the handwritten mdBook source tree, then make the copy
        # writable so generated pages can be overlaid into it.
        cp -R ${source}/docs/manual/. "$out"
        chmod -R u+w "$out/src"

        # Overlay pages and shell snippets derived from evaluated configuration.
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (path: file: ''
            install -D -m 0644 ${file} "$out/src/${path}"
          '') generatedStoreFiles
        )}

        # nixosOptionsDoc already gives us CommonMark. These fixups make its
        # declaration links and explicit anchors suitable for the assembled book:
        # - strip the source store prefix from displayed declaration paths;
        # - replace unusable file:// links with inline-code declaration names;
        # - preserve option anchor IDs with explicit HTML <h2> elements;
        # - remove escaped dots after the heading has become raw HTML.
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

        # Append RFC145 documentation from modules/ and lib/ to the semantic
        # scopes page. Prefix anchors with the source path to avoid collisions
        # between files, and demote nixdoc headings beneath each file heading.
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

  # Render separately so docsSource remains useful for editor previews,
  # inspection, or a different renderer in the future.
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
