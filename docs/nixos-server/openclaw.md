# OpenClaw

OpenClaw's Gateway remains in Docker on the NixOS server. nginx exposes the
loopback-bound Gateway to the LAN, while mutable app and auth state remain under
`/var/lib/apps/openclaw` and `/var/lib/apps/openclaw-auth`. The NixOS wiring is
in `hosts/nixos-server/apps.nix`; the mutable Gateway config is
`/var/lib/apps/openclaw/openclaw.json`. The container image is pinned by digest
so an upstream `latest` tag rollback cannot run an older binary against newer
state.

## Execution and repository access

OpenClaw is intentionally host-root-equivalent through the loopback
`openclaw-host` administration path. The repository wrapper is an operational
convenience rather than a sandbox: it reuses the host bridge, preserves checkout
ownership, avoids running GitHub CLI as root, and selects dedicated GitHub
credentials for repository work.

General host administration follows this path:

```text
OpenClaw Docker Gateway
  → openclaw-host
  → loopback SSH as openclaw-admin
  → optional sudo
  → host command
```

Repository operations follow this path:

```text
OpenClaw Docker Gateway
  → openclaw-repository
  → openclaw-host
  → loopback SSH as openclaw-admin
  → sudo openclaw-repository-host
  → git or gh as joshan
```

Gateway exec is the resilient default. The bundled `repository-access` skill
uses this policy:

1. Prefer a connected app-backed macOS node that advertises `system.run` and
   `system.which`, and work in `/Users/joshan/.files`.
2. Ignore disconnected or commandless headless nodes. Selection is based on
   live capabilities; no node ID is persisted.
3. If no suitable Mac node is connected, use the existing Docker Gateway host
   bridge and the server checkout at `/home/joshan/.files`.

Use one checkout per task and never create an additional clone. The server
wrapper provides these entry points:

```sh
openclaw-repository git files status --short --branch
openclaw-repository git infrastructure-docs status --short --branch
openclaw-repository gh issue list --repo joshan-kana/.files --limit 5
```

Host administration, Git transport, and GitHub API access use separate
credentials:

- `/root/secrets/openclaw-host-admin-id_ed25519` is the loopback-only host
  administration key. It remains separate from the GitHub Git key.
- `/root/secrets/openclaw-github-id_ed25519` is the dedicated OpenClaw Git key.
  Its public key is an account authentication key attached to `joshan-kana`.
  The repository wrapper uses it instead of Joshan's broader personal key;
  Joshan's existing personal key remains untouched.
- `/root/secrets/openclaw-github.env` contains the GitHub API token.

For Git, root starts a temporary SSH agent as `joshan`, then loads the dedicated
root-owned key into it. Git runs as `joshan` with Joshan's home and existing
commit identity. `IdentitiesOnly=yes` and a temporary copy of the dedicated
public key ensure SSH selects only the matching agent identity; strict GitHub
host-key checking remains enabled and interactive prompting is disabled.

For GitHub API work, root reads the token file and passes only `GH_TOKEN` to the
invoked `gh` child. `gh` runs as `joshan`, stores no token in Joshan's home, and
uses an ephemeral configuration directory under `/run`. Issues, comments, pull
requests, reviews, and project mutations appear on GitHub as `joshan-kana`, the
account represented by the token.

Because `openclaw-admin` has unrestricted sudo, OpenClaw can access these
root-owned credentials through the intended administration path. File ownership
keeps ordinary host processes separated; it is not a security boundary against
OpenClaw.

If the API token is not provisioned, create it without displaying the value:

```sh
read -rsp 'GitHub token: ' OPENCLAW_GITHUB_TOKEN && printf '\n' && \
  printf 'GH_TOKEN=%s\n' "$OPENCLAW_GITHUB_TOKEN" | \
  sudo install -m 0400 -o root -g root /dev/stdin /root/secrets/openclaw-github.env; \
unset OPENCLAW_GITHUB_TOKEN
```

The token must have access to both private repositories and the issue, pull
request, Project, and account SSH-key mutations OpenClaw is expected to perform.

`docs/infrastructure-docs` is a separate Git repository and submodule. For a
documentation change, create a branch inside the submodule, commit and push it,
open a draft `infrastructure-docs` PR, then update the parent pointer in a
separate `.files` commit. Never point `.files` at an unpushed submodule commit.

## Ollama Proxy

OpenClaw should always talk to Ollama through the local server endpoint:

```text
http://127.0.0.1:11434
```

The Ollama models actually run on Joshan's Mac. The NixOS server runs a small
nginx proxy on `127.0.0.1:11434` and forwards that local endpoint to whichever
Mac Ollama path is currently reachable.

The selection policy is:

1. Prefer the LAN path at home by resolving `Joshans-MacBook-Pro.local` and
   writing the resolved numeric LAN IP into nginx config.
2. Fall back to the Mac's Tailscale address, `100.87.66.20`, when the LAN path
   is not reachable.

This keeps OpenClaw stable because the provider base URL never changes, even
when the Mac moves between LAN and Tailscale paths.

## Why nginx Uses Numeric Upstreams

The generated nginx include at `/run/openclaw-ollama-proxy.conf` should contain a
numeric upstream such as:

```text
proxy_pass http://192.168.1.108:11434;
```

or:

```text
proxy_pass http://100.87.66.20:11434;
```

It should not contain a `.local` hostname. nginx resolves normal hostnames during
config load/reload, so a `.local` upstream can make nginx fail to start or reload
when mDNS is unavailable or the Mac is off. A numeric fallback keeps nginx
healthy. If the Mac or Ollama is unavailable, Ollama requests can fail with a
backend/proxy error, but nginx itself remains running.

## Polling Timer

`openclaw-ollama-proxy.timer` periodically runs
`openclaw-ollama-proxy.service`. The timer polls about every 30 seconds.

The oneshot service:

1. resolves the Mac's mDNS name to a LAN IP,
2. checks the LAN Ollama `/api/tags` endpoint,
3. checks the Tailscale Ollama `/api/tags` endpoint if LAN fails,
4. writes `/run/openclaw-ollama-proxy.conf` only when the selected upstream
   changes, and
5. reloads nginx only after a config change.

This keeps the Raspberry Pi 4 work small: each poll does a short mDNS lookup and
one or two short HTTP checks, and nginx is not reloaded when the selected
upstream is unchanged.

## Verification

Run this on the NixOS server:

```sh
systemctl --failed
systemctl status docker-openclaw.service configure-openclaw-gateway.service openclaw-ollama-proxy.timer openclaw-ollama-proxy.service nginx.service --no-pager -l
systemctl list-timers openclaw-ollama-proxy.timer --all --no-pager
cat /run/openclaw-ollama-proxy.conf
curl -sS -i --max-time 8 http://127.0.0.1:11434/api/tags | sed -n '1,20p'
sudo docker exec openclaw openclaw models list --provider ollama
sudo docker exec openclaw openclaw config get tools.exec
sudo docker exec openclaw openclaw nodes status --json
gh --version
sudo /run/current-system/sw/bin/openclaw-repository-host gh auth status --hostname github.com
sudo /run/current-system/sw/bin/openclaw-repository-host gh issue list --repo joshan-kana/.files --limit 5
sudo /run/current-system/sw/bin/openclaw-repository-host gh pr list --repo joshan-kana/.files --limit 5
sudo /run/current-system/sw/bin/openclaw-repository-host gh repo view joshan-kana/infrastructure-docs
sudo /run/current-system/sw/bin/openclaw-repository-host git files ls-remote git@github.com:joshan-kana/.files.git HEAD
sudo /run/current-system/sw/bin/openclaw-repository-host git infrastructure-docs ls-remote git@github.com:joshan-kana/infrastructure-docs.git HEAD
```

Expected healthy state:

- `systemctl --failed` reports `0 loaded units listed`.
- `openclaw-ollama-proxy.timer` is active and has a populated `NEXT` run.
- `nginx.service` is active.
- `/run/openclaw-ollama-proxy.conf` contains a numeric IP, not `.local`.
- `http://127.0.0.1:11434/api/tags` returns the Mac Ollama models when the Mac
  and Ollama are reachable.
- OpenClaw lists the Ollama models through the `ollama` provider.
- `tools.exec.host` is `gateway` and has no fixed `node` value.
- The connected app-backed Mac node reports `system.run`; a harmless node exec
  starts in `/Users/joshan/.files`.
- The wrapper's Git and `gh` reads succeed for both repositories.

Mac-offline fallback can be verified safely without disconnecting the Mac: use
Gateway exec explicitly and run
`openclaw-repository git files status --short --branch`. This simulates the same
path the skill selects when no suitable Mac node is connected.

## Operational Notes

The Mac runs Ollama; the Raspberry Pi 4 only hosts the OpenClaw gateway and the
local proxy. When the Mac is asleep, off, or Ollama is stopped, the local proxy
can return a backend error. That is expected. The important property is that
nginx and OpenClaw remain healthy and the polling timer picks up the Mac again
when Ollama becomes reachable.

## OpenRouter Model Lanes

OpenClaw is configured with three scoped OpenRouter API keys, each presented as a
custom OpenAI-compatible provider:

| Provider               | Lane       | Models                                          |
| ---------------------- | ---------- | ----------------------------------------------- |
| `openrouter-zdr`       | ZDR        | MiniMax M3, GLM 5.2                             |
| `openrouter-deepseek`  | non-ZDR    | DeepSeek V4 Flash, DeepSeek V4 Pro               |
| `openrouter-free`      | FREE       | Free models (non-sensitive prompts only)         |

The default model is `openrouter-zdr/minimax/minimax-m3`.

All three lanes are independent. Each key has a guardrail enforced by OpenRouter
(server-side), and the keys are independently scoped — they cannot overwrite
each other.

### Server Secret Files

| File                                      | Variable                    |
| ----------------------------------------- | --------------------------- |
| `/root/secrets/server-zdr-openrouter.env` | `OPENROUTER_ZDR_API_KEY`    |
| `/root/secrets/server-deepseek-openrouter.env` | `OPENROUTER_DEEPSEEK_API_KEY` |
| `/root/secrets/server-free-openrouter.env` | `OPENROUTER_FREE_API_KEY`   |

These files are `root:root 0600` and are passed to the OpenClaw container through
NixOS `environmentFiles`. The container references each key through an
environment-backed SecretRef in `openclaw.json`.

### Privacy Boundaries

- ZDR is the default lane for all agents.
- DeepSeek is an explicit non-ZDR lane.
- Free is an explicit non-sensitive lane.
- There is **no automatic fallback** between any of the three OpenRouter lanes.
  The default fallback list is empty.
- There is also no automatic fallback to Together, direct DeepSeek, or Ollama.

### Listing Models

```sh
sudo docker exec openclaw openclaw models list --provider openrouter-zdr
sudo docker exec openclaw openclaw models list --provider openrouter-deepseek
sudo docker exec openclaw openclaw models list --provider openrouter-free
sudo docker exec openclaw openclaw models status
```

### Switching Models

In chat or CLI, use the full provider-prefixed model reference:

```text
openrouter-zdr/minimax/minimax-m3
openrouter-zdr/z-ai/glm-5.2
openrouter-deepseek/deepseek/deepseek-v4-flash
openrouter-deepseek/deepseek/deepseek-v4-pro
openrouter-free/<org>/<model>:free
```

Or use the configured aliases:

```text
OR ZDR MiniMax M3
OR ZDR GLM 5.2
OR DeepSeek V4 Flash (non-ZDR)
OR DeepSeek V4 Pro (non-ZDR)
```

### Important Warnings

- **Free lane**: Use only for non-sensitive prompts. Do not send personal data
  or credentials to free-model providers.
- **Model availability**: OpenRouter model availability can change. The static
  free-model list must be revalidated via the OpenRouter `/api/v1/models/user`
  endpoint before changing it.

### Existing Providers Preserved

Ollama, Together AI, and direct DeepSeek remain configured and available as
explicit legacy/credit-balance options alongside the three OpenRouter lanes.

## Rollback

Repository and host access have four independent rollback controls.

### Disable GitHub API access

Move or remove `/root/secrets/openclaw-github.env`. Authenticated `gh`
operations then fail closed. Git-over-SSH remains available.

### Disable OpenClaw Git transport

Revoke the account authentication key titled `OpenClaw nixos-server Git`, then
move or remove:

```text
/root/secrets/openclaw-github-id_ed25519
/root/secrets/openclaw-github-id_ed25519.pub
```

This disables the wrapper's Git transport without affecting Joshan's original
personal key.

### Emergency return to the previous Git key

Temporarily restore this setting in `hosts/nixos-server/apps.nix`, then rebuild:

```nix
privateKeyPath = "${secretsDir}/id_ed25519";
```

This reuses the broader personal credential and is only an emergency fallback.

### Disable host administration

Separately remove or restrict the mounted host-admin private key, the loopback
authorized key, or the `openclaw-admin` sudo rule. This changes the intended
OpenClaw operating model and is not part of normal repository-access rollback.

To roll back the complete NixOS deployment, run
`sudo nixos-rebuild switch --rollback` or boot the previous generation. Existing
OpenClaw app/auth data and both repository checkouts are retained.
