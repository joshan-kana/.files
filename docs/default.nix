{
  configurations,
  lib,
  pkgs,
  semanticScopeOptions,
  source,
}:

let
  server = configurations.nixos-server;

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
    optionIdPrefix = "opt-dotfiles-";
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

  hostsMarkdown = ''
    # Hosts

    This page is generated from the evaluated flake configurations.

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

    This table is generated from each host's evaluated `dotfiles.resolvedScopes` tree.

    ${scopeTableHeader}
    ${lib.concatStringsSep "\n" scopeTableRows}
  '';

  hostsSource = pkgs.writeText "dotfiles-hosts.md" hostsMarkdown;
  scopesSource = pkgs.writeText "dotfiles-scopes.md" scopesMarkdown;

  docsSource =
    pkgs.runCommand "dotfiles-docs-source"
      {
        nativeBuildInputs = [
          pkgs.coreutils
          pkgs.gnused
        ];
      }
      ''
        set -euo pipefail
        cp -R ${source}/docs/manual/. "$out"
        chmod -R u+w "$out"
        mkdir -p "$out/src/reference" "$out/data"

        {
          echo '# dotfiles option reference'
          echo
          echo 'Generated from the project-owned evaluated Nix option tree.'
          echo
          sed -E \
            -e "s#${source}/##g" \
            -e 's#\[([^]]+)\]\(file://[^)]*\)#`\1`#g' \
            ${optionDocs.optionsCommonMark}
        } > "$out/src/reference/options.md"

        install -m 0644 ${hostsSource} "$out/src/reference/hosts.md"
        install -m 0644 ${scopesSource} "$out/src/reference/scopes.md"
        cp ${optionDocs.optionsJSON}/share/doc/nixos/options.json "$out/data/options.json"

        for required in \
          src/reference/options.md \
          src/reference/hosts.md \
          src/reference/scopes.md \
          data/options.json; do
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
  inherit book docsSource;
}
