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
- `/run/openclaw-ollama-proxy.conf` contains a numeric IP, not `.local`.
- `http://127.0.0.1:11434/api/tags` returns the Mac Ollama models when the Mac
  and Ollama are reachable.
- OpenClaw lists the Ollama models through the `ollama` provider.

## Operational Notes

The Mac runs Ollama; the Raspberry Pi 4 only hosts the OpenClaw gateway and the
local proxy. When the Mac is asleep, off, or Ollama is stopped, the local proxy
can return a backend error. That is expected. The important property is that
nginx and OpenClaw remain healthy and the polling timer picks up the Mac again
when Ollama becomes reachable.
