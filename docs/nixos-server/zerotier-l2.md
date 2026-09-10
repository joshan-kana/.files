# ZeroTier L2 Bridge

## Purpose

`nixos-server` runs a self-hosted ZeroTier controller and bridges one ZeroTier
network onto the home Ethernet segment. The bridge carries Ethernet multicast
and broadcast traffic so desktop clients can use normal mDNS and Bonjour while
away from home.

Tailscale remains the primary routed remote-access overlay. ZeroTier is limited
to the Layer-2 use case; it does not provide a default route or DNS service.

## Addressing

The physical LAN remains `192.168.1.0/24`. The router DHCP pool remains
`192.168.1.100-192.168.1.199`.

The ZeroTier network uses:

| Item | Value |
| --- | --- |
| Managed route | `192.168.0.0/23` |
| Dynamic assignment pool | `192.168.1.201-192.168.1.239` |
| Default route | None |
| Managed DNS | None |

The assignment pool is separate from the router's DHCP range. The wider `/23`
managed route is intentional: when a laptop returns home, the physical
`192.168.1.0/24` route is more specific and wins over the ZeroTier route.
Individual ZeroTier client addresses are disposable and must not be used as
stable service identifiers.

## Server Network Layout

NetworkManager owns the bridge:

```text
br0
├── end0
└── zt-home-l2          ZeroTier home-l2 TAP
```

The server's normal LAN identities belong to `br0`:

```text
192.168.1.3  nixos-server
192.168.1.2  AdGuard
```

`end0` has no Layer-3 configuration of its own. LAN-facing firewall rules use
the logical `br0` interface through `dotfiles.server.lan.interface`.

OpenTofu writes `/var/lib/zerotier-one/devicemap` before the server joins the
network, mapping the deterministic `home-l2` network ID to `zt-home-l2`. ZeroTier
therefore creates one predictable TAP without making the controller or client
address static. A udev rule attaches only that exact TAP to `br0`; other
ZeroTier networks are not bridged onto the physical LAN.

## Controller State

The controller uses the normal ZeroTier service directory:

```text
/var/lib/zerotier-one
```

The identity in `identity.secret` is persistent. Network IDs are derived from
the controller identity, so replacing it creates a different controller rather
than reconnecting the existing one.

The encrypted `apps` restic job includes `/var/lib/zerotier-one`, including:

- `identity.secret`
- `controller.d`
- the local network membership state
- the OpenTofu state file

Do not copy the server's Tailscale lifecycle onto ZeroTier. Tailscale remains
intentionally ephemeral; the ZeroTier controller identity must survive rebuilds
and restores.

## OpenTofu Ownership

`infra/zerotier` manages controller state through the ZeroTier service API on
`127.0.0.1:9993`. The API is not exposed to the LAN.

OpenTofu owns:

- the private `home-l2` network;
- the `/23` managed route;
- the dynamic client address pool;
- the server's `activeBridge` authorization;
- the `home-l2` to `zt-home-l2` ZeroTier device mapping;
- the server's own membership in the network;
- authorization and bridge policy for additional members.

The local backend stores state at:

```text
/var/lib/zerotier-one/opentofu.tfstate
```

This keeps controller state off the Git worktree and inside the encrypted
server backup set.

### Initialize and plan

Run OpenTofu on `nixos-server` after the controller-enabled NixOS configuration
is active:

```sh
cd /home/joshan/.files

export TF_VAR_controller_node_id="$(sudo zerotier-cli info | awk '{print $3}')"
export TF_VAR_controller_token="$(sudo cat /var/lib/zerotier-one/authtoken.secret)"
export API_DATA_IS_SENSITIVE=true

sudo --preserve-env=TF_VAR_controller_node_id,TF_VAR_controller_token,API_DATA_IS_SENSITIVE \
  nix shell --inputs-from . nixpkgs#opentofu -c tofu -chdir=infra/zerotier init

sudo --preserve-env=TF_VAR_controller_node_id,TF_VAR_controller_token,API_DATA_IS_SENSITIVE \
  nix shell --inputs-from . nixpkgs#opentofu -c tofu -chdir=infra/zerotier plan
```

Review the plan before applying it. The first apply creates the deterministic
network ID `<controller-node-id>000001`, authorizes the server as an Ethernet
bridge, writes the `zt-home-l2` device mapping, and only then joins the server to
the network. The bridge member receives no managed ZeroTier IP.

Apply only after the server bridge and client prerequisites below are ready:

```sh
sudo --preserve-env=TF_VAR_controller_node_id,TF_VAR_controller_token,API_DATA_IS_SENSITIVE \
  nix shell --inputs-from . nixpkgs#opentofu -c tofu -chdir=infra/zerotier apply
```

Print the generated network ID with:

```sh
sudo --preserve-env=TF_VAR_controller_node_id,TF_VAR_controller_token,API_DATA_IS_SENSITIVE \
  nix shell --inputs-from . nixpkgs#opentofu -c tofu -chdir=infra/zerotier output -raw network_id
```

## Adding Desktop Clients

Install the normal ZeroTier client on the desktop and note its ten-character
node ID. Add that public node ID to the `members` map used by OpenTofu. A sample
shape is kept in `infra/zerotier/members.auto.tfvars.example`.

For a normal desktop member:

```hcl
members = {
  macbook = {
    node_id = "0123456789"
  }
}
```

The node ID is not an authentication secret. Never commit `identity.secret`,
the local service API token, or OpenTofu state.

After the member is authorized, join the generated network from the client.
Normal desktop clients should accept managed private routes and addresses, but
must not accept a ZeroTier default route or DNS configuration.

## macOS Validation Gate

Do not make the server bridge dependent on an untested Mac client. Validate the
current ZeroTier release on the current macOS release first.

Before enabling managed ZeroTier configuration on the Mac:

1. Record the current default route and active Tailscale state.
2. Install and start ZeroTier without changing the server bridge.
3. Join the test network and confirm normal Internet access remains intact.
4. Confirm no unexpected default route points at loopback.
5. Confirm the ZeroTier interface receives only the expected managed private
   route/address.
6. Confirm Tailscale continues to reach normal tailnet peers.

There is an upstream ZeroTier report for macOS 26.2 where enabling managed
configuration can install an invalid loopback default route. Treat this as a
hard deployment gate until the installed client is verified on the Mac.

Once ZeroTier provides the Mac's remote home-LAN path, disable acceptance of
the `192.168.1.0/24` Tailscale subnet route on that Mac. Tailscale can remain
active for direct tailnet peers. This prevents the more-specific Tailscale `/24`
from overriding the ZeroTier `/23` and creating asymmetric LAN paths.

## Server Cutover

Changing `end0` from a Layer-3 interface into a bridge port can interrupt the
connection to a headless server. Perform the first cutover with local console
access or another independently verified recovery path.

Before switching:

```sh
nix eval --json \
  .#nixosConfigurations.nixos-server.config.networking.networkmanager.ensureProfiles.profiles

nix build \
  .#nixosConfigurations.nixos-server.config.system.build.toplevel \
  --no-link
```

After switching, verify:

```sh
ip -br link show br0 end0
ip -br addr show br0
nmcli connection show --active
ip route
systemctl status NetworkManager zerotierone --no-pager
sudo zerotier-cli info
```

Expected server addresses are on `br0`, not `end0`:

```text
192.168.1.3/24
192.168.1.2/24
```

After OpenTofu has created and joined `home-l2`, verify the ZeroTier interface
is a bridge port:

```sh
ip -d link show zt-home-l2
bridge link show dev zt-home-l2
sudo zerotier-cli listnetworks
```

Then test mDNS in both directions from a remote desktop and a physical LAN
machine before relying on the bridge for service discovery.

## Rollback

Keep the previous NixOS generation available during the first cutover. If the
bridge configuration breaks LAN access, roll back from the local console:

```sh
sudo nixos-rebuild switch --rollback
```

If only the ZeroTier overlay is unhealthy, leave the physical `br0`/`end0`
bridge intact and stop ZeroTier while investigating:

```sh
sudo systemctl stop zerotierone
```

Do not delete `controller.d`, `identity.secret`, or the OpenTofu state as a
network troubleshooting step. Those files are persistent control-plane state,
not disposable cache files.
