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

  serverMarkdown = ''
    # NixOS server reference

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

  runbookEnvironment = ''
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
  serverSource = pkgs.writeText "dotfiles-server.md" serverMarkdown;
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
        mkdir -p "$out/src/generated" "$out/src/reference" "$out/data"

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

        install -m 0644 ${hostsSource} "$out/src/reference/hosts.md"
        install -m 0644 ${scopesSource} "$out/src/reference/scopes.md"
        install -m 0644 ${serverSource} "$out/src/reference/server.md"
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
          src/reference/server.md \
          src/generated/server-env.sh \
          src/generated/backup-reference.md \
          src/generated/storage-reference.md \
          data/options.json \
          data/reference.json; do
          test -s "$out/$required"
        done
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
