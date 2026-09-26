# OpenClaw

This page documents the OpenClaw runtime wiring on the NixOS server.

## Local Gateway

OpenClaw runs natively as `openclaw-gateway.service` on the NixOS server and
is exposed through nginx. The service uses the first-party NixOS module from the
`nix-openclaw` flake with its first-party slim `openclaw-gateway` package.

The server keeps OpenClaw state under `/var/lib/apps/openclaw`, including
`/var/lib/apps/openclaw/openclaw.json`, which OpenClaw owns directly. Nix owns
the service boundary, secrets, runtime tools, proxying, and host integration.
The service runs `openclaw config validate` before startup so an incompatible
configuration prevents startup after an upgrade instead of being silently
accepted.

The native service runs as `openclaw:appdata-editors`, matching the server-app
service-user pattern used elsewhere on the host.

## Host and repository access

OpenClaw is intentionally a privileged server worker, like Hermes Agent and
Open WebUI Computer. The openclaw service user has passwordless sudo and sees
Joshan's home through a bindfs mapping at /home/joshan.

The bindfs mapping presents Joshan-owned files as writable by openclaw inside
the service namespace while preserving joshan ownership on the underlying
filesystem. Repository work therefore uses ordinary Git commands directly:

```text
git -C /home/joshan/.files <git arguments...>
git -C /home/joshan/.files/docs/infrastructure-docs <git arguments...>
gh <arguments...>
```

/root/secrets/github-self-hosted-agents.env supplies GH_TOKEN. Git rewrites
<git@github.com>: remotes to HTTPS and uses gh auth git-credential, so OpenClaw
does not need a dedicated GitHub SSH key, an SSH agent, or a localhost admin
account.

OpenClaw is host-root-equivalent by design. sudo is the normal NixOS sudo
wrapper exposed on the service PATH; there is no separate privilege transport.

## Repository verification

From an OpenClaw shell, these should work directly:

```text
gh api user --jq .login
git -C /home/joshan/.files status --short --branch
git -C /home/joshan/.files/docs/infrastructure-docs status --short --branch
```

The GitHub identity should be joshan-kana, and files created through the
bindfs-mapped home should remain owned by joshan on the host.

## Host access rollback

- GitHub API: move or remove /root/secrets/github-self-hosted-agents.env.
- Host administration: remove the openclaw sudo rule.
- Home access: remove the /run/openclaw-home bindfs mapping.
- Complete deployment: before switching back to the former Docker generation,
  restore state ownership with sudo chown -R 1000:1000 /var/lib/apps/openclaw,
  then run sudo nixos-rebuild switch --rollback or boot the previous generation.

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

Each poll does a short mDNS lookup and one or two short HTTP checks, and nginx
is not reloaded when the selected upstream is unchanged.

## Verification

Run this on the NixOS server:

```sh
systemctl --failed
systemctl status openclaw-gateway.service nginx.service --no-pager -l
systemctl status openclaw-ollama-proxy.timer openclaw-ollama-proxy.service --no-pager -l
systemctl list-timers openclaw-ollama-proxy.timer --all --no-pager
cat /run/openclaw-ollama-proxy.conf
curl -sS -I --max-time 8 http://127.0.0.1:18789/ | sed -n '1,12p'
curl -sS -i --max-time 8 http://127.0.0.1:11434/api/tags | sed -n '1,20p'
```

Expected healthy state:

- `systemctl --failed` reports `0 loaded units listed`.
- `openclaw-gateway.service` is active.
- `openclaw-ollama-proxy.timer` is active and has a populated `NEXT` run.
- `nginx.service` is active.
- `/run/openclaw-ollama-proxy.conf` contains a numeric IP, not `.local`.
- `http://127.0.0.1:11434/api/tags` returns the Mac Ollama models when the Mac
  and Ollama are reachable.

## Operational Notes

The Mac runs Ollama; the NixOS server hosts the OpenClaw gateway and the local
proxy. When the Mac is asleep, off, or Ollama is stopped, the local proxy
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

These files are `root:root 0600` and are loaded by
`openclaw-gateway.service` through systemd `EnvironmentFile=`. OpenClaw
references each key through an environment-backed SecretRef in
`openclaw.json`.

### Privacy Boundaries

- ZDR is the default lane for all agents.
- DeepSeek is an explicit non-ZDR lane.
- Free is an explicit non-sensitive lane.
- There is **no automatic fallback** between any of the three OpenRouter lanes.
  The default fallback list is empty.
- There is also no automatic fallback to Together, direct DeepSeek, or Ollama.

### Listing Models

Use the Control UI for normal provider and model inspection. OpenClaw is not
installed globally on the host; the service invokes the first-party gateway
package directly. A separately invoked CLI would also need the gateway's state
paths and secret environment to be an equivalent diagnostic context. Service
failures and provider startup errors are available through
`journalctl -u openclaw-gateway.service`.

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
