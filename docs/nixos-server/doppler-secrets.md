# Doppler Secrets

Doppler is the source of truth for provisioned static machine runtime secrets.
Bitwarden remains the source of truth for human-facing credentials and the
recovery copies of the Doppler Service Tokens needed to bootstrap a machine.

Applications do not call Doppler directly. They continue to consume ordinary
runtime files.

## Scope Model

Use one Doppler config for each access boundary that should receive a different
Service Token. The project, environment, and config names are intentionally not
hard-coded in `.files`; the Service Token itself identifies the config.

Current boundaries are:

- `nixos-server` system secrets;
- `joshan` user secrets on `nixos-server`;
- `joshan` user secrets on `nixos-arm-parallels`;
- `joshan` user secrets on `nixos-orbstack`;
- `joshan` user secrets on the generic `nixos` host.

Use the same model for macOS once it is managed by `.files`: Mac user
secrets should have their own config and token instead of being shared with a VM.

Each normal machine scope uses a read-only Service Token. Keep a recovery copy
of each read-only token in Bitwarden and install only the token needed by that
scope.

## Runtime Paths

System secrets on `nixos-server` remain under:

```text
/root/secrets
```

Primary-user secrets remain under:

```text
~/.secrets
```

Doppler token files are separate from the secrets they unlock:

```text
/var/lib/doppler-secrets/system.env
~/.config/doppler-secrets/user.env
```

The files contain only:

```text
DOPPLER_TOKEN=<read-only service token>
```

The system token file is root-only. The user token file is readable only by the
primary user.

## Secret Names

A runtime filename is mapped to a Doppler key by uppercasing it and replacing
`.` and `-` with `_`.

| Runtime file | Doppler key |
| --- | --- |
| `n8n.env` | `N8N_ENV` |
| `restic-password` | `RESTIC_PASSWORD` |
| `rclone.conf` | `RCLONE_CONF` |
| `openclaw-github-id_ed25519` | `OPENCLAW_GITHUB_ID_ED25519` |

Nix evaluation rejects a scope if two filenames normalize to the same key.

## Declaring Secrets

Modules declare runtime requirements through:

```nix
dotfiles.secrets.requiredFiles = [ secretPath ];
```

This is provider-neutral. A server app uses the same local path value for both
the application configuration and `requiredFiles`.

Files that the runtime application legitimately updates also declare:

```nix
dotfiles.secrets.mutableFiles = [ secretPath ];
```

Mutable files are restored from Doppler when absent but are not overwritten by
a normal sync once they exist. Current mutable files are `rclone.conf`,
whose OAuth token state can be refreshed by rclone, and the Beeper `bbctl`
credential JSON, which can change during login/logout.

For these mutable files, Doppler is a bootstrap snapshot rather than the live
post-startup source of truth. The application-owned local file can diverge after
provisioning; refreshing that snapshot is deliberate maintenance rather than a
normal read-only sync.

When an enabled app stops declaring a previously Doppler-managed file, the next
successful sync removes that stale file from the local cache.

## Sync Behaviour

`doppler-secrets-system.service` refreshes the root-owned scope.
`doppler-secrets-user.service` refreshes the primary-user scope.

Both services:

- run at boot/login when their token file exists;
- stage values before replacing live files;
- leave previous local files intact if the Doppler fetch fails;
- do not block individual applications;
- have no periodic timer enabled by default.

This keeps normal boot independent of the Doppler API once a last-known-good
cache exists. A fresh machine with no cache can still have secret-dependent
services fail until the initial sync completes.

Refresh explicitly with:

```sh
sudo systemctl start doppler-secrets-system
systemctl --user start doppler-secrets-user
```

## Initial Migration

Do not rotate credentials as part of this migration. Import the exact current
values first and validate the new provisioning path.

After deploying this configuration, review the system import without writing:

```sh
sudo doppler-secrets-import-system --check
```

Review the user scope:

```sh
doppler-secrets-import-user --check
```

The output contains only filename-to-key mappings, never secret values.

For each target Doppler config, create a temporary write-capable Service Token
and load it without placing it in shell history:

```sh
read -rsp 'Temporary Doppler write token: ' DOPPLER_TOKEN
export DOPPLER_TOKEN
printf '\n'
```

Apply the system import:

```sh
sudo --preserve-env=DOPPLER_TOKEN doppler-secrets-import-system --apply
```

Or the user import:

```sh
doppler-secrets-import-user --apply
```

Then remove and revoke the temporary write credential:

```sh
unset DOPPLER_TOKEN
```

Normal machine operation uses a new read-only Service Token for the same config.

For the system scope:

```sh
read -rsp 'Read-only Doppler token: ' DOPPLER_TOKEN
printf '\n'
sudo install -d -m 700 /var/lib/doppler-secrets
printf 'DOPPLER_TOKEN=%s\n' "$DOPPLER_TOKEN" \
  | sudo install -m 600 -o root -g root /dev/stdin /var/lib/doppler-secrets/system.env
unset DOPPLER_TOKEN
sudo systemctl start doppler-secrets-system
```

For the primary-user scope:

```sh
read -rsp 'Read-only Doppler token: ' DOPPLER_TOKEN
printf '\n'
install -d -m 700 "$HOME/.config/doppler-secrets"
printf 'DOPPLER_TOKEN=%s\n' "$DOPPLER_TOKEN" \
  | install -m 600 /dev/stdin "$HOME/.config/doppler-secrets/user.env"
unset DOPPLER_TOKEN
systemctl --user start doppler-secrets-user
```

Store recovery copies of the read-only Service Tokens in Bitwarden.

## Validation

Check state without printing secret contents:

```sh
systemctl status doppler-secrets-system --no-pager
systemctl --user status doppler-secrets-user --no-pager

sudo find /root/secrets -maxdepth 1 -type f -printf '%f\n' | sort
find "$HOME/.secrets" -maxdepth 1 -type f -printf '%f\n' | sort
```

A failed refresh must not delete the previous local files.

## Raspberry Pi Image Bootstrap

The built image still contains no runtime secret values.

After boot:

1. Copy the `.files` checkout to `/home/joshan/.files`.
2. Install the `nixos-server` system read-only Doppler token from Bitwarden.
3. Start `doppler-secrets-system.service`.
4. Install the server user read-only token and start
   `doppler-secrets-user.service`.
5. Restore application data with Restic.
6. Rebuild or restart any service that failed before the initial secret sync.

The Mac no longer needs to copy a plaintext secret bundle to the server.

## Traditional NixOS Installer Bootstrap

For a conventional install such as the OptiPlex, use the installer environment
only as a temporary bootstrap session.

Start with the GitHub and Doppler tools:

```sh
nix shell nixpkgs#gh nixpkgs#git nixpkgs#doppler nixpkgs#jq
```

Keep the installer GitHub session under `/run`:

```sh
export GH_CONFIG_DIR=/run/gh
mkdir -p "$GH_CONFIG_DIR"
gh auth login --web --git-protocol https
gh repo clone joshan-kana/.files /tmp/.files
```

Retrieve the `nixos-server` system read-only Doppler token from Bitwarden:

```sh
read -rsp 'Read-only Doppler token: ' DOPPLER_TOKEN
export DOPPLER_TOKEN
printf '\n'
```

If Restic credentials are needed before the installed system has booted,
materialize only those files under `/run`:

```sh
install -d -m 700 /run/nixos-secrets
payload="$(doppler secrets download --no-file --format json)"
jq -erj '.RCLONE_CONF' <<<"$payload" > /run/nixos-secrets/rclone.conf
jq -erj '.RESTIC_PASSWORD' <<<"$payload" > /run/nixos-secrets/restic-password
chmod 600 /run/nixos-secrets/*
unset payload
```

Use those temporary files for the restore. Before rebooting the installed
system, install the read-only system token at
`/mnt/var/lib/doppler-secrets/system.env` and the corresponding user
token under the installed user's home. The normal boot services then
materialize the full scoped secret set.

Remove temporary installer state before finishing:

```sh
unset DOPPLER_TOKEN
rm -rf /run/gh /run/nixos-secrets
```

The bootstrap dependency is therefore Bitwarden plus temporary GitHub login,
not a local plaintext secret archive.
