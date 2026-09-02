{
  lib,
  pkgs,
  kakehashiPackage ? null,
}:

let
  languageRegistry = builtins.fromJSON (builtins.readFile ./nix-embedded-languages.json);

  formatterInputs = [
    pkgs.ast-grep
    pkgs.coreutils
    pkgs.fish
    pkgs.gofumpt
    pkgs.llvmPackages.clang-tools
    pkgs.nix
    pkgs.prettier
    pkgs.ruff
    pkgs.rustfmt
    pkgs.shellcheck
    pkgs.shfmt
    pkgs.stylua
    pkgs.taplo
  ];

  lspInputs = formatterInputs ++ [
    pkgs.basedpyright
    pkgs.bash-language-server
    pkgs.fish-lsp
    pkgs.gopls
    pkgs.lua-language-server
    pkgs.solargraph
    pkgs.rust-analyzer
    pkgs.sqls
    pkgs.typescript-language-server
    pkgs.vscode-langservers-extracted
    pkgs.marksman
    pkgs.yaml-language-server
  ];

  package = pkgs.writeShellApplication {
    name = "nix-embedded";
    runtimeInputs = formatterInputs;
    text = ''
      state_dir="''${NIX_EMBEDDED_STATE_DIR:-''${TMPDIR:-/tmp}/nix-embedded-state-$UID}"
      mkdir -p "$state_dir"
      export NIX_STATE_DIR="$state_dir"
      export NIX_EMBEDDED_LANGUAGE_REGISTRY=${./nix-embedded-languages.json}
      export NIX_EMBEDDED_AST_GREP=${pkgs.ast-grep}/bin/ast-grep
      export NIX_EMBEDDED_NIX_INSTANTIATE=${pkgs.nix}/bin/nix-instantiate
      export NIX_EMBEDDED_RUFF=${pkgs.ruff}/bin/ruff
      export NIX_EMBEDDED_SHELLCHECK=${pkgs.shellcheck}/bin/shellcheck
      exec ${pkgs.python3}/bin/python3 ${./nix-embedded.py} "$@"
    '';
    meta.description = "Format and lint languages embedded in annotated Nix strings";
  };

  mkHostLspPackage =
    {
      name,
      runtimeInputs,
    }:
    pkgs.writeShellApplication {
      inherit name runtimeInputs;
      text = ''
        state_dir="''${NIX_EMBEDDED_STATE_DIR:-''${TMPDIR:-/tmp}/nix-embedded-state-$UID}"
        mkdir -p "$state_dir"
        export NIX_STATE_DIR="$state_dir"
        if [[ ! -d "''${HOME:-}" || ! -w "''${HOME:-}" ]]; then
          export HOME="$state_dir/home"
          mkdir -p "$HOME"
        fi

        source_dir="$(mktemp -d "$state_dir/lsp-source.XXXXXX")"
        trap 'rm -rf "$source_dir"' EXIT
        cp ${./nix-embedded.py} "$source_dir/nix-embedded.py"
        cp ${./nix-embedded-lsp.py} "$source_dir/nix-embedded-lsp.py"
        cp ${./nix-embedded-source-map.py} "$source_dir/nix-embedded-source-map.py"
        cp ${./nix-embedded-lsp-entry.py} "$source_dir/nix-embedded-lsp-entry.py"

        export NIX_EMBEDDED_LANGUAGE_REGISTRY=${./nix-embedded-languages.json}
        export NIX_EMBEDDED_AST_GREP=${pkgs.ast-grep}/bin/ast-grep
        export NIX_EMBEDDED_NIXFMT=${pkgs.nixfmt}/bin/nixfmt
        export NIX_EMBEDDED_NIX_INSTANTIATE=${pkgs.nix}/bin/nix-instantiate
        export NIX_EMBEDDED_RUFF=${pkgs.ruff}/bin/ruff
        export NIX_EMBEDDED_SHELLCHECK=${pkgs.shellcheck}/bin/shellcheck
        ${pkgs.python3}/bin/python3 "$source_dir/nix-embedded-lsp-entry.py" "$@"
      '';
      meta.description = "Nix-aware embedded-language specialist LSP";
    };

  hostLspPackage = mkHostLspPackage {
    name = "nix-embedded-host-lsp";
    runtimeInputs = lspInputs;
  };

  hostLspTestPackage = mkHostLspPackage {
    name = "nix-embedded-host-lsp-test";
    runtimeInputs = [
      pkgs.ast-grep
      pkgs.basedpyright
      pkgs.bash-language-server
      pkgs.coreutils
      pkgs.nix
      pkgs.ruff
    ];
  };

  registryGrammars = lib.mapAttrs (
    _language: spec: pkgs.tree-sitter-grammars.${"tree-sitter-${spec.grammar}"}
  ) languageRegistry;
  grammars = registryGrammars // {
    nix = pkgs.tree-sitter-grammars.tree-sitter-nix;
    regex = pkgs.tree-sitter-grammars.tree-sitter-regex;
  };
  nixQueries = pkgs.vimPlugins.nvim-treesitter-parsers.nix.associatedQuery;

  injectionQuery = pkgs.writeText "nix-embedded-injections.scm" (
    lib.concatStringsSep "\n\n" (
      lib.mapAttrsToList (
        language: spec:
        let
          aliases = lib.concatStringsSep "|" (map lib.escapeRegex spec.aliases);
        in
        ''
          ((comment) @_nix_embedded_language
            .
            (indented_string_expression
              (string_fragment) @injection.content)
            (#match? @_nix_embedded_language "(?i)^/\\*\\s*(${aliases})\\s*\\*/$")
            (#set! injection.language "${language}")
            (#set! injection.combined))
        ''
      ) languageRegistry
    )
  );

  kakehashiData = pkgs.runCommand "nix-embedded-kakehashi-data" { } ''
    mkdir -p "$out/parser" "$out/queries"
    ${lib.concatMapStringsSep "\n" (
      language:
      let
        grammar = grammars.${language};
      in
      ''
        if [ -f ${grammar}/parser ]; then
          ln -s ${grammar}/parser "$out/parser/${language}.so"
        fi
        if [ -d ${grammar}/queries ]; then
          mkdir -p "$out/queries/${language}"
          for query in ${grammar}/queries/*; do
            [ -e "$query" ] && ln -s "$query" "$out/queries/${language}/"
          done
        fi
      ''
    ) (builtins.attrNames grammars)}

    # Use nvim-treesitter's mature Nix highlighting/locals queries, but keep
    # injection discovery aligned exactly with our explicit annotation registry.
    rm -rf "$out/queries/nix"
    mkdir -p "$out/queries/nix"
    for query in ${nixQueries}/queries/nix/*; do
      [ -e "$query" ] && ln -s "$query" "$out/queries/nix/"
    done
    rm -f "$out/queries/nix/injections.scm"
    ln -s ${injectionQuery} "$out/queries/nix/injections.scm"
  '';

  lspPackage =
    if kakehashiPackage == null then
      hostLspPackage
    else
      pkgs.writeShellApplication {
        name = "nix-embedded-lsp";
        runtimeInputs = [
          kakehashiPackage
          hostLspPackage
          pkgs.nixd
        ];
        text = ''
          export KAKEHASHI_DATA_DIR=${kakehashiData}

          config_args=(--config-file ${./kakehashi-base.toml})
          state_dir="''${NIX_EMBEDDED_STATE_DIR:-''${TMPDIR:-/tmp}/nix-embedded-state-$UID}"
          ${pkgs.coreutils}/bin/install -d -m 700 "$state_dir"
          rendered_config="$(${pkgs.coreutils}/bin/mktemp "$state_dir/kakehashi-project.XXXXXX.toml")"
          trap '${pkgs.coreutils}/bin/rm -f "$rendered_config"' EXIT

          if ${pkgs.python3}/bin/python3 - "$rendered_config" <<'PY'
          import os
          import sys
          from pathlib import Path

          start = Path(os.environ.get("NIX_EMBEDDED_WORKSPACE", Path.cwd())).resolve()
          for root in (start, *start.parents):
              config = root / "kakehashi.toml"
              if not config.is_file():
                  continue
              Path(sys.argv[1]).write_text(
                  config.read_text().replace("''${workspaceFolder}", str(root))
              )
              raise SystemExit(0)
          raise SystemExit(1)
          PY
          then
            config_args+=(--config-file "$rendered_config")
          fi

          ${lib.getExe' kakehashiPackage "kakehashi"} "''${config_args[@]}" "$@"
        '';
        meta.description = "Kakehashi-powered Nix and embedded-language LSP";
      };
in
{
  inherit
    hostLspPackage
    kakehashiData
    lspPackage
    package
    ;

  formatter = {
    command = lib.getExe package;
    options = [ "format" ];
    includes = [ "*.nix" ];
    priority = 4;
  };

  # Re-run nixfmt after native embedded formatters have rewritten string contents.
  finalNixfmtFormatter = {
    command = lib.getExe pkgs.nixfmt;
    includes = [ "*.nix" ];
    priority = 5;
  };

  lintCheck =
    {
      src,
      excludes ? [ ],
    }:
    let
      excludeArgs = lib.concatMapStringsSep " " (path: "--exclude ${lib.escapeShellArg path}") excludes;
    in
    pkgs.runCommand "nix-embedded-lint" { } ''
      ${lib.getExe package} self-test
      ${lib.getExe hostLspTestPackage} --self-test
      ${lib.getExe package} lint ${excludeArgs} ${src}
      touch "$out"
    '';

  lspCheck =
    assert kakehashiPackage != null;
    pkgs.runCommand "nix-embedded-lsp-check" { } ''
      ${lib.getExe' kakehashiPackage "kakehashi"} config schema >/dev/null
      ${pkgs.python3}/bin/python3 ${./nix-embedded-lsp-smoke.py} ${lib.getExe lspPackage}
      touch "$out"
    '';
}
