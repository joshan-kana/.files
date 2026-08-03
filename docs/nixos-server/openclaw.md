# OpenClaw

## Host and repository access

The Docker Gateway reaches the host through `openclaw-host`, which uses loopback
SSH as `openclaw-admin`. Repository operations use `openclaw-repository`, which
reuses that transport and runs Git and GitHub CLI as `joshan`.

```sh
openclaw-repository git files <git arguments...>
openclaw-repository git infrastructure-docs <git arguments...>
openclaw-repository gh <gh arguments...>
```

Git uses `/root/secrets/openclaw-github-id_ed25519`; GitHub API operations use
`/root/secrets/openclaw-github.env` and appear as `joshan-kana`. OpenClaw is
intentionally host-root-equivalent; these wrappers preserve checkout ownership
and provide an interface, not a security boundary against OpenClaw.

## Repository smoke tests

```sh
sudo docker exec openclaw openclaw-repository gh api user --jq .login
sudo docker exec openclaw openclaw-repository git files status --short --branch
sudo docker exec openclaw openclaw-repository git infrastructure-docs status --short --branch
```

## Privacy default

MiniMax M3 on `openrouter-zdr` remains the default privacy lane. DeepSeek V4
Flash is an explicit session override; there is no automatic provider fallback.

## Rollback

| Access | Disable |
| --- | --- |
| GitHub API | Move or remove `/root/secrets/openclaw-github.env`. |
| Git over SSH | Revoke `OpenClaw nixos-server Git`, then move or remove the dedicated keypair. |
| Host administration | Remove or restrict the host-admin key or `openclaw-admin` sudo access. |
| Complete deployment | Run `sudo nixos-rebuild switch --rollback` or boot the previous generation. |

Repository-access rollback does not modify Joshan's existing
`/root/secrets/id_ed25519` key.
