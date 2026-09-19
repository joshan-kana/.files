{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) mkIf;
  inherit (config.dotfiles.users) primary;
  cfg = config.dotfiles.secrets.doppler;

  secretName =
    file:
    lib.toUpper (
      lib.replaceStrings
        [
          "-"
          "."
        ]
        [
          "_"
          "_"
        ]
        file
    );

  filesFor =
    targetDir:
    map (path: {
      file = builtins.baseNameOf path;
      mutable = builtins.elem path config.dotfiles.secrets.mutableFiles;
    }) (builtins.filter (path: builtins.dirOf path == targetDir) config.dotfiles.secrets.requiredFiles);

  systemFiles = filesFor cfg.system.targetDir;
  userFiles = filesFor cfg.user.targetDir;

  hasUniqueSecretNames =
    files:
    let
      names = map (entry: secretName entry.file) files;
    in
    builtins.length names == builtins.length (lib.unique names);

  manifestFor =
    name: files:
    pkgs.writeText "${name}.json" (
      builtins.toJSON (
        builtins.listToAttrs (
          map (entry: {
            name = secretName entry.file;
            value = entry;
          }) files
        )
      )
    );

  mkTools =
    {
      name,
      files,
      targetDir,
    }:
    let
      manifest = manifestFor "doppler-${name}-secrets" files;

      sync = pkgs.writeShellApplication {
        name = "doppler-secrets-sync-${name}";
        runtimeInputs = with pkgs; [
          coreutils
          doppler
          jq
          util-linux
        ];
        text = ''
          target_dir=${lib.escapeShellArg targetDir}
          manifest=${lib.escapeShellArg manifest}

          umask 077
          install -d -m 0700 "$target_dir"
          exec 9>"$target_dir/.doppler-sync.lock"
          flock 9

          stage="$(mktemp -d "$target_dir/.doppler-sync.XXXXXX")"
          trap 'rm -rf -- "$stage"' EXIT

          payload="$(doppler secrets download --no-file --format json)"

          declare -A expected=()
          while IFS=$'\t' read -r secret file mutable; do
            expected["$file"]=1
            if ! jq -e --arg secret "$secret" 'has($secret)' <<<"$payload" >/dev/null; then
              printf 'Doppler config is missing required secret %s for %s\n' "$secret" "$file" >&2
              exit 1
            fi
          done < <(jq -r 'to_entries[] | [.key, .value.file, (.value.mutable | tostring)] | @tsv' "$manifest")

          while IFS=$'\t' read -r secret file mutable; do
            if [[ "$mutable" == true && -e "$target_dir/$file" ]]; then
              continue
            fi
            jq -erj --arg secret "$secret" '.[$secret]' <<<"$payload" >"$stage/$file"
            chmod 0600 "$stage/$file"
          done < <(jq -r 'to_entries[] | [.key, .value.file, (.value.mutable | tostring)] | @tsv' "$manifest")

          while IFS=$'\t' read -r _ file _; do
            if [[ -e "$stage/$file" ]]; then
              mv -f -- "$stage/$file" "$target_dir/$file"
            fi
          done < <(jq -r 'to_entries[] | [.key, .value.file, (.value.mutable | tostring)] | @tsv' "$manifest")

          state="$target_dir/.doppler-managed-files"
          if [[ -f "$state" ]]; then
            while IFS= read -r old_file; do
              [[ -n "$old_file" ]] || continue
              if [[ -z "''${expected[$old_file]+x}" ]]; then
                rm -f -- "$target_dir/$old_file"
              fi
            done <"$state"
          fi

          jq -r '.[].file' "$manifest" >"$stage/.doppler-managed-files"
          chmod 0600 "$stage/.doppler-managed-files"
          mv -f -- "$stage/.doppler-managed-files" "$state"
        '';
      };

      importSecrets = pkgs.writeShellApplication {
        name = "doppler-secrets-import-${name}";
        runtimeInputs = with pkgs; [
          coreutils
          doppler
          jq
        ];
        text = ''
          target_dir=${lib.escapeShellArg targetDir}
          manifest=${lib.escapeShellArg manifest}

          mode="''${1:-}"
          case "$mode" in
            ""|--check) apply=false ;;
            --apply) apply=true ;;
            *)
              printf 'usage: %s [--check|--apply]\n' "''${0##*/}" >&2
              exit 2
              ;;
          esac

          missing=0
          while IFS=$'\t' read -r secret file _; do
            if [[ ! -r "$target_dir/$file" ]]; then
              printf 'missing: %s\n' "$target_dir/$file" >&2
              missing=1
              continue
            fi
            printf '%s -> %s\n' "$file" "$secret"
          done < <(jq -r 'to_entries[] | [.key, .value.file, (.value.mutable | tostring)] | @tsv' "$manifest")

          (( missing == 0 )) || exit 1
          [[ "$apply" == true ]] || exit 0

          : "''${DOPPLER_TOKEN:?Set a temporary write-capable DOPPLER_TOKEN for the target config}"

          while IFS=$'\t' read -r secret file _; do
            doppler secrets set --no-interactive "$secret" <"$target_dir/$file" >/dev/null
            printf 'uploaded: %s\n' "$file" >&2
          done < <(jq -r 'to_entries[] | [.key, .value.file, (.value.mutable | tostring)] | @tsv' "$manifest")
        '';
      };
    in
    {
      inherit importSecrets sync;
    };

  systemTools = mkTools {
    name = "system";
    files = systemFiles;
    inherit (cfg.system) targetDir;
  };

  userTools = mkTools {
    name = "user";
    files = userFiles;
    inherit (cfg.user) targetDir;
  };
in
{
  assertions = [
    {
      assertion = !cfg.system.enable || systemFiles != [ ];
      message = "Doppler system secret provisioning requires at least one managed file.";
    }
    {
      assertion = !cfg.user.enable || userFiles != [ ];
      message = "Doppler user secret provisioning requires at least one managed file.";
    }
    {
      assertion = builtins.all (
        path: builtins.elem path config.dotfiles.secrets.requiredFiles
      ) config.dotfiles.secrets.mutableFiles;
      message = "Every mutable secret file must also be registered as a required secret file.";
    }
    {
      assertion = hasUniqueSecretNames systemFiles;
      message = "Doppler system secret filenames collide after normalization.";
    }
    {
      assertion = hasUniqueSecretNames userFiles;
      message = "Doppler user secret filenames collide after normalization.";
    }
  ];

  doppler = _: {
    environment.systemPackages = [
      pkgs.doppler
    ]
    ++ lib.optionals cfg.system.enable [
      systemTools.importSecrets
      systemTools.sync
    ];

    systemd.tmpfiles.rules =
      lib.optionals cfg.system.enable [
        "d ${builtins.dirOf cfg.system.tokenFile} 0700 root root - -"
        "d ${cfg.system.targetDir} 0700 root root - -"
      ]
      ++ lib.optionals cfg.user.enable [
        "d ${builtins.dirOf cfg.user.tokenFile} 0700 ${primary.name} users - -"
        "d ${cfg.user.targetDir} 0700 ${primary.name} users - -"
      ];

    systemd.services.doppler-secrets-system = mkIf cfg.system.enable {
      description = "Refresh system secrets from Doppler";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      unitConfig.ConditionPathExists = cfg.system.tokenFile;
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = cfg.system.tokenFile;
        ExecStart = lib.getExe systemTools.sync;
        ExecStartPost = "${pkgs.systemd}/bin/systemd-tmpfiles --create --prefix=${cfg.system.targetDir}";
      };
    };

    systemd.timers.doppler-secrets-system =
      mkIf (cfg.system.enable && cfg.system.syncInterval != null)
        {
          description = "Periodically refresh system secrets from Doppler";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnUnitActiveSec = cfg.system.syncInterval;
            Persistent = true;
            Unit = "doppler-secrets-system.service";
          };
        };

    home =
      _:
      mkIf cfg.user.enable {
        home.packages = [
          pkgs.doppler
          userTools.importSecrets
          userTools.sync
        ];

        systemd.user.services.doppler-secrets-user = {
          Unit = {
            Description = "Refresh user secrets from Doppler";
            ConditionPathExists = cfg.user.tokenFile;
          };
          Service = {
            Type = "oneshot";
            EnvironmentFile = cfg.user.tokenFile;
            ExecStart = lib.getExe userTools.sync;
          };
          Install.WantedBy = [ "default.target" ];
        };

        systemd.user.timers.doppler-secrets-user = mkIf (cfg.user.syncInterval != null) {
          Unit.Description = "Periodically refresh user secrets from Doppler";
          Timer = {
            OnUnitActiveSec = cfg.user.syncInterval;
            Persistent = true;
            Unit = "doppler-secrets-user.service";
          };
          Install.WantedBy = [ "timers.target" ];
        };
      };
  };
}
