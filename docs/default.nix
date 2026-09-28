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
  filesystemValue = fs: if fs == null then "_Not configured_" else "`${fs.device}` (`${fs.fsType}`)";

  hostIdentityMarkdown =
    name: host:
    let
      inherit (host) config;
      primaryUser = config.dotfiles.users.primary;
      primaryHomePath = "${primaryUser.homeRoot}/${primaryUser.name}";
    in
    ''
      # `${name}`

      | Setting | Evaluated value |
      | --- | --- |
      | Platform | `${host.pkgs.stdenv.hostPlatform.system}` |
      | Profile | `${config.dotfiles.profile.name}` |
      | Hostname | `${config.networking.hostName}` |
      | Primary user | `${primaryUser.name}` |
      | Primary home | `${primaryHomePath}` |
      | Repository | `${config.dotfiles.paths.repoPath}` |
      | Container | ${if config.boot.isContainer or false then "yes" else "no"} |
      | Root filesystem | ${filesystemValue (filesystem config "/")} |
      | Boot filesystem | ${filesystemValue (filesystem config "/boot")} |
      | Home filesystem | ${filesystemValue (filesystem config "/home")} |
    '';

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
  ) allScopeNames;

  containers = builtins.attrNames serverConfig.virtualisation.oci-containers.containers;
  resticBackups = serverConfig.services.restic.backups;
  appBackup = resticBackups.apps;
  secretBackup = resticBackups.secrets;
  retention = serverConfig.dotfiles.backups.retention;
  storage = serverConfig.dotfiles.server.storage;
  lan = serverConfig.dotfiles.server.lan;
  firewall = serverConfig.networking.firewall;
  lanFirewall = lib.attrByPath [ lan.interface ] { } firewall.interfaces;
  primary = serverConfig.dotfiles.users.primary;
  primaryHome = "${primary.homeRoot}/${primary.name}";
  immichMediaRoot = serverConfig.services.immich.mediaLocation;
  paperlessDataRoot = serverConfig.services.paperless.dataDir;
  paperlessMediaRoot = serverConfig.services.paperless.mediaDir;
  paperlessConsumeRoot = serverConfig.services.paperless.consumptionDir;
  paperlessBackupRoot = serverConfig.services.postgresqlBackup.location;

  referenceModel = {
    hosts = lib.mapAttrs (_: host: {
      system = host.pkgs.stdenv.hostPlatform.system;
      profile = host.config.dotfiles.profile.name;
      hostName = host.config.networking.hostName;
      repoPath = host.config.dotfiles.paths.repoPath;
      primaryUser = host.config.dotfiles.users.primary.name;
      container = host.config.boot.isContainer or false;
      enabledScopes = map (row: lib.concatStringsSep "." row.path) (
        lib.filter (row: row.enabled) (flattenScopes [ ] host.config.dotfiles.resolvedScopes)
      );
    }) configurations;
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
      lan = {
        inherit (lan) interface;
        inherit (lan) subnet;
        inherit (lan) gateway;
        inherit (lan) serverIp;
        dnsIp = lan.dns.serviceIp;
      };
      firewall = {
        global = {
          tcpPorts = firewall.allowedTCPPorts;
          udpPorts = firewall.allowedUDPPorts;
          tcpPortRanges = firewall.allowedTCPPortRanges;
          udpPortRanges = firewall.allowedUDPPortRanges;
        };
        interfaces = lib.mapAttrs (_: interface: {
          tcpPorts = interface.allowedTCPPorts;
          udpPorts = interface.allowedUDPPorts;
          tcpPortRanges = interface.allowedTCPPortRanges;
          udpPortRanges = interface.allowedUDPPortRanges;
        }) firewall.interfaces;
      };
      inherit containers;
      backups = {
        apps = {
          inherit (appBackup) repository;
          inherit (appBackup) paths;
          exclude = appBackup.exclude or [ ];
          schedule = appBackup.timerConfig.OnCalendar or null;
        };
        secrets = {
          inherit (secretBackup) repository;
          inherit (secretBackup) paths;
          schedule = secretBackup.timerConfig.OnCalendar or null;
        };
        inherit retention;
      };
    };
  };

  referenceJson = pkgs.writeText "dotfiles-reference.json" (builtins.toJSON referenceModel);

  mdList =
    values:
    if values == [ ] then
      "- _None_"
    else
      lib.concatMapStringsSep "\n" (value: "- `${toString value}`") values;
  ports = values: if values == [ ] then "_None_" else lib.concatStringsSep ", " (map toString values);
  portRanges =
    values:
    if values == [ ] then
      "_None_"
    else
      lib.concatStringsSep ", " (map (range: "${toString range.from}-${toString range.to}") values);

  hostsMarkdown = ''
    # Hosts

    | Host | System | Profile |
    | --- | --- | --- |
    ${lib.concatMapStringsSep "\n" (
      name:
      let
        host = configurations.${name};
      in
      "| `${name}` | `${host.pkgs.stdenv.hostPlatform.system}` | `${host.config.dotfiles.profile.name}` |"
    ) hostNames}
  '';

  scopesMarkdown = ''
    # Semantic scopes

    ${scopeTableHeader}
    ${lib.concatStringsSep "\n" scopeTableRows}
  '';

  serverDetailsMarkdown = ''
    ## Storage

    | Setting | Evaluated value |
    | --- | --- |
    | Application data root | `${storage.appData.root}` |
    | Bulk data root | `${storage.dataRoot.path}` |
    | ZFS pool | `${storage.dataRoot.poolName}` |
    | Snapshot interval | ${toString storage.snapshots.intervalMinutes} minutes |

    ## Network

    | Setting | Evaluated value |
    | --- | --- |
    | LAN interface | `${lan.interface}` |
    | LAN subnet | `${lan.subnet}` |
    | Gateway | `${lan.gateway}` |
    | Server IP | `${lan.serverIp}` |
    | DNS service IP | `${lan.dns.serviceIp}` |
    | Global TCP firewall ports | ${ports firewall.allowedTCPPorts} |
    | Global UDP firewall ports | ${ports firewall.allowedUDPPorts} |
    | Global TCP firewall ranges | ${portRanges firewall.allowedTCPPortRanges} |
    | Global UDP firewall ranges | ${portRanges firewall.allowedUDPPortRanges} |
    | `${lan.interface}` TCP firewall ports | ${ports (lanFirewall.allowedTCPPorts or [ ])} |
    | `${lan.interface}` UDP firewall ports | ${ports (lanFirewall.allowedUDPPorts or [ ])} |
    | `${lan.interface}` TCP firewall ranges | ${portRanges (lanFirewall.allowedTCPPortRanges or [ ])} |
    | `${lan.interface}` UDP firewall ranges | ${portRanges (lanFirewall.allowedUDPPortRanges or [ ])} |

    ## OCI containers

    ${mdList containers}

    ## Backups

    ### Application data

    Repository: `${appBackup.repository}`

    ${mdList appBackup.paths}

    ### Secrets and account state

    Repository: `${secretBackup.repository}`

    ${mdList secretBackup.paths}

    ### Retention

    | Class | Count |
    | --- | ---: |
    | Hourly | ${toString retention.hourly} |
    | Daily | ${toString retention.daily} |
    | Weekly | ${toString retention.weekly} |
    | Monthly | ${toString retention.monthly} |
  '';

  hostMarkdown = lib.mapAttrs (
    name: host:
    hostIdentityMarkdown name host
    + lib.optionalString (name == "nixos-server") "\n${serverDetailsMarkdown}"
  ) configurations;

  hostSources = lib.mapAttrs (
    name: markdown: pkgs.writeText "dotfiles-host-${name}.md" markdown
  ) hostMarkdown;

  hostEnvironmentSources = lib.mapAttrs (
    name: host: pkgs.writeText "dotfiles-host-${name}-env.sh" (hostRunbookEnvironment name host)
  ) configurations;

  summaryMarkdown = ''
    # Summary

    - [Hosts](reference/hosts.md)
    ${lib.concatMapStringsSep "\n" (
      name:
      "  - [`${name}`](reference/hosts/${name}.md)\n    - [Install or recover](runbooks/install/${name}.md)"
    ) hostNames}
    - [Semantic scopes](reference/scopes.md)
    - [dotfiles options](reference/options.md)
    - [Backup and restore](runbooks/backup-restore.md)
    - [Vault ZFS storage](runbooks/vault-storage.md)
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

  backupMarkdown = ''
    | Setting | Evaluated value |
    | --- | --- |
    | Application data root | `${storage.appData.root}` |
    | Vault root | `${storage.dataRoot.path}` |
    | App backup repository | `${appBackup.repository}` |
    | Secret backup repository | `${secretBackup.repository}` |
    | Snapshot interval | ${toString storage.snapshots.intervalMinutes} minutes |
    | App backup schedule | `${appBackup.timerConfig.OnCalendar}` |
    | Secret backup schedule | `${secretBackup.timerConfig.OnCalendar}` |

    **Application backup paths**

    ${mdList appBackup.paths}

    **Application backup exclusions**

    ${mdList (appBackup.exclude or [ ])}

    **Secret/account backup paths**

    ${mdList secretBackup.paths}
  '';

  storageMarkdown = ''
    | Setting | Evaluated value |
    | --- | --- |
    | Application data | `${storage.appData.root}` |
    | Vault mount | `${storage.dataRoot.path}` |
    | Vault pool | `${storage.dataRoot.poolName}` |
    | Snapshot interval | ${toString storage.snapshots.intervalMinutes} minutes |
    | Retention | ${toString retention.hourly} hourly / ${toString retention.daily} daily / ${toString retention.weekly} weekly / ${toString retention.monthly} monthly |
  '';

  hostsSource = pkgs.writeText "dotfiles-hosts.md" hostsMarkdown;
  scopesSource = pkgs.writeText "dotfiles-scopes.md" scopesMarkdown;
  runbookEnvironmentSource = pkgs.writeText "dotfiles-server-env.sh" runbookEnvironment;
  backupSource = pkgs.writeText "dotfiles-backup-reference.md" backupMarkdown;
  storageSource = pkgs.writeText "dotfiles-storage-reference.md" storageMarkdown;

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
        mkdir -p "$out/src/generated/hosts" "$out/src/reference/hosts" "$out/data"

        {
          echo '# dotfiles option reference'
          echo
          sed -E \
            -e "s#${source}/##g" \
            -e 's#\[([^]]+)\]\(file://[^)]*\)#`\1`#g' \
            -e 's|^## (.*) \{#([^}]+)\}$|<h2 id="\2">\1</h2>|' \
            -e '/^<h2 id=/ s/\\\././g' \
            ${optionDocsCommonMark}
        } > "$out/src/reference/options.md"

        install -m 0644 ${summarySource} "$out/src/SUMMARY.md"
        install -m 0644 ${hostsSource} "$out/src/reference/hosts.md"
        install -m 0644 ${scopesSource} "$out/src/reference/scopes.md"
        ${lib.concatMapStringsSep "\n" (name: ''
          install -m 0644 ${hostSources.${name}} "$out/src/reference/hosts/${name}.md"
          install -m 0644 ${hostEnvironmentSources.${name}} "$out/src/generated/hosts/${name}.sh"
        '') hostNames}
        install -m 0644 ${runbookEnvironmentSource} "$out/src/generated/server-env.sh"
        install -m 0644 ${backupSource} "$out/src/generated/backup-reference.md"
        install -m 0644 ${storageSource} "$out/src/generated/storage-reference.md"
        chmod u+w "$out/src/reference/scopes.md"

        while IFS= read -r -d "" file; do
          grep -q '/\*\*' "$file" || continue
          relative="''${file#${source}/}"
          anchor="$(printf '%s' "$relative" | tr '/.' '--')"
          rendered="$(nixdoc --file "$file" --category "" --description "" --prefix "" --anchor-prefix "$anchor-")"
          [ -n "$(printf '%s' "$rendered" | tr -d '[:space:]')" ] || continue
          printf '\n## `%s`\n\n' "$relative" >> "$out/src/reference/scopes.md"
          printf '%s\n' "$rendered" \
            | sed -E 's/^(#{1,5})([[:space:]])/#\1\2/' \
            >> "$out/src/reference/scopes.md"
        done < <(
          find ${source}/modules ${source}/lib -type f -name '*.nix' -print0 | sort -z
        )

        cp ${optionDocs.optionsJSON}/share/doc/nixos/options.json "$out/data/options.json"
        cp ${referenceJson} "$out/data/reference.json"

        for required in \
          src/reference/options.md \
          src/reference/hosts.md \
          src/reference/scopes.md \
          src/generated/server-env.sh \
          src/generated/backup-reference.md \
          src/generated/storage-reference.md \
          data/options.json \
          data/reference.json; do
          test -s "$out/$required"
        done

        ${lib.concatMapStringsSep "\n" (name: ''
          test -s "$out/src/reference/hosts/${name}.md"
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
