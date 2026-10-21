# Tailscale LAN DNS preference

The Mac's launch agent follows macOS network-change notifications. It keeps the
Tailscale tunnel enabled, but disables Tailscale-managed DNS while an authenticated
Tailscale ping to `nixos-server` uses a directly attached physical network route
(no gateway). Otherwise it restores Tailscale-managed DNS, including for remote
LANs that happen to use the same IPv4 subnet.

At home, ordinary DNS comes from the Mac's Wi-Fi configuration and AdGuard.
Technitium already resolves the tailnet's machine names and `.home` aliases,
including the Tailscale-only Parallels VM. A newly added split DNS zone must also
be accessible through local DNS if it is needed while home.
The watcher does not react to manual DNS preference edits until the next
network change, preventing feedback loops with the VPN app.

The watcher uses the vendor executable inside `/Applications/Tailscale.app`. It
responds to macOS dynamic network state instead of polling, and restores
Tailscale-managed DNS when stopped. No static Mac IP, SSID, or Tailscale IP is
encoded in the package.
