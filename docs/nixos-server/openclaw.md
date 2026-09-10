# OpenClaw

This page documents the OpenClaw runtime wiring on the NixOS server.

## Local Gateway

OpenClaw runs on the NixOS server and is exposed through nginx. The server keeps
OpenClaw's app state under `/var/lib/apps/openclaw` and its auth/profile state
under `/var/lib/apps/openclaw-auth`.

The OpenClaw container is configured from
`profiles/nixos-server/hosted-stack.nix`. OpenClaw's mutable config is written to
`/var/lib/apps/openclaw/openclaw.json` on the host and mounted into the
container.

## Host and repository access

The Docker Gateway reaches the host through `openclaw-host`, which connects over
loopback SSH as `openclaw-admin`. Repository operations use
`openclaw-repository`, which reuses that transport and runs Git and GitHub CLI as
`joshan`.

```sh
openclaw-repository git files <git arguments...>
openclaw-repository git infrastructure-docs <git arguments...>
openclaw-repository gh <gh arguments...>
```

Git uses `/root/secrets/openclaw-github-id_ed25519`; GitHub API operations use
`/root/secrets/openclaw-github.env` and appear as `joshan-kana`.

OpenClaw is intentionally host-root-equivalent. These wrappers preserve checkout
ownership and provide a consistent interface; they are not security boundaries
against OpenClaw.

## Repository verification

```sh
sudo docker exec openclaw openclaw-repository gh api user --jq .login
sudo docker exec openclaw openclaw-repository git files status --short --branch
sudo docker exec openclaw openclaw-repository git infrastructure-docs status --short --branch
```

## Repository-access rollback

- GitHub API: move or remove `/root/secrets/openclaw-github.env`.
- Git over SSH: revoke `OpenClaw nixos-server Git`, then move or remove its
  dedicated keypair.
- Host administration: remove or restrict the host-admin key or
  `openclaw-admin` sudo access.
- Complete deployment: run `sudo nixos-rebuild switch --rollback` or boot the
  previous generation.

This rollback does not modify Joshan's existing
`/root/secrets/id_ed25519` key.

## Ollama Proxy

OpenClaw should always talk to Ollama through the local server endpoint:

```text
http://127.0.0.1:11434
```

The Ollama models actually run on Joshan's Mac. The NixOS server runs a small
nginx proxy on `127.0.0.1:11434` and forwards that local endpoint to whichever
Mac Ollama path is currently reachable.

The selection policy is:

1. Resolve `Joshans-MacBook-Pro.local` through mDNS and write the resolved
   numeric address into nginx config when Ollama is reachable.
2. Use the normal LAN advertisement while the Mac is home and the ZeroTier
   `home-l2` advertisement while the Mac is away.
3. Return HTTP 503 from the local proxy when the Mac or Ollama is unavailable.

This keeps OpenClaw stable because the provider base URL never changes while
avoiding any dependency on a fixed Tailscale or ZeroTier client address.

## Why nginx Uses Numeric Upstreams

The generated nginx include at `/run/openclaw-ollama-proxy.conf` contains a
numeric upstream while the Mac is reachable, for example:

```text
proxy_pass http://192.168.1.x:11434;
```

It should never contain a `.local` hostname or a fixed overlay-network client
address. nginx resolves normal hostnames during config load/reload, so a `.local`
upstream can make nginx fail to start or reload when mDNS is unavailable or the
Mac is off.

When no discovered Ollama endpoint is reachable, the include contains:

```text
return 503;
```

This keeps nginx healthy and makes unavailability explicit without persisting a
stale or hard-coded remote address.

## Polling Timer

`openclaw-ollama-proxy.timer` periodically runs
`openclaw-ollama-proxy.service`. The timer polls about every 30 seconds.

The oneshot service:

1. resolves the Mac's mDNS name to an IPv4 address,
2. checks the discovered Ollama `/api/tags` endpoint,
3. writes either a numeric `proxy_pass` or `return 503` to
   `/run/openclaw-ollama-proxy.conf`, and
4. reloads nginx only after the generated config changes.

This keeps the Raspberry Pi 4 work small: each poll does a short mDNS lookup and
one short HTTP check, and nginx is not reloaded when the generated config is
unchanged.

## Verification

Run this on the NixOS server:

```sh
systemctl --failed
systemctl status openclaw-ollama-proxy.timer openclaw-ollama-proxy.service nginx.service --no-pager -l
systemctl list-timers openclaw-ollama-proxy.timer --all --no-pager
cat /run/openclaw-ollama-proxy.conf
curl -sS -i --max-time 8 http://127.0.0.1:11434/api/tags | sed -n '1,20p'
sudo docker exec openclaw openclaw models list --provider ollama
```

Expected healthy state:

- `systemctl --failed` reports `0 loaded units listed`.
- `openclaw-ollama-proxy.timer` is active and has a populated `NEXT` run.
- `nginx.service` is active.
- `/run/openclaw-ollama-proxy.conf` contains either a numeric `proxy_pass` or
  `return 503`, never `.local` or a fixed overlay client address.
- `http://127.0.0.1:11434/api/tags` returns the Mac Ollama models when the Mac
  and Ollama are reachable.
- OpenClaw lists the Ollama models through the `ollama` provider.

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
