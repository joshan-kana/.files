# Roaming DNS

This Technitium DNS app post-processes the responses for explicitly configured roaming hosts. DHCP continues assigning addresses and maintaining native A records. The post-processor is necessary because those records take priority over Technitium APP records.

A background poll resolves each host's current DHCP A record, checks its LAN TCP endpoint, and resolves the configured fallback FQDN. This can be a Tailscale name today or a different private-network provider later. DNS queries never perform network health checks. Healthy local queries retain the DHCP address; healthy remote AAAA queries retain Technitium's existing DNS64 mapping. Remote IPv4 queries use the fallback address to avoid collisions with a remote `192.168.1.0/24`. Backend queries originating at the server's own `192.168.1.3` address also take the fallback path because they are indistinguishable from 4via6 traffic; local clients should use AdGuard rather than bypassing it. When the LAN endpoint fails, both local and remote queries use the fallback DNS target; an absent fallback AAAA produces NODATA so clients can use its A record.

**Client DNS behavior:** No client-side daemon, DNS preference changes, or host-specific configuration is installed. LAN queries through AdGuard retain the DHCP address while the LAN endpoint is healthy; DNS forwarded through the existing remote 4via6 path uses the overlap-safe fallback A record. These paths are not necessarily equivalent to the client's physical location: with Tailscale DNS enabled at home, a Mac can send its queries through the remote path and receive the fallback even while directly attached to the home LAN. Technitium sees the forwarded query's source, not the original device, so it cannot reliably distinguish those cases without an identifiable DNS request path. The extension therefore does not guarantee LAN-first selection for every home client using Tailscale DNS.

The DNS answer TTL is bounded to 10 seconds to make transitions responsive. A DNS lookup that cannot reach either endpoint fails rather than returning a stale, potentially reassigned LAN address. TCP health checks determine reachability, not host identity; SSH host-key verification still belongs to the SSH client.

## Ownership

The global package overlay builds this app against the selected Technitium package; the `networking.dns` scope on `nixos-server` consumes it and installs the assembly and configuration immediately before Technitium starts. The app's device list is defined there. The normal Technitium DHCP scope, leases, DNS zone, other apps, and remote-network routes remain application-managed. Adding a roaming host requires only its canonical `.home` name, stable fallback DNS name, and health-check port.

## Verification

The isolated test harness is in `tests/technitium-roaming`. Use the repository's Nix-provided .NET SDK to compile and run it. It verifies LAN availability, address changes, fallback-network resolution, lease expiry, DNS64 preservation, overlapping remote IPv4, and unrelated hostnames.

For live tests, confirm Technitium loads `RoamingDns` without errors and query the ordinary LAN resolver and the remote 4via6 resolver for both A and AAAA while the target device is at home and away. Check `mac.home` from `nixos-server` over SSH and via AdGuard from a LAN client. Repeat after DHCP renewal. Do not delete the DHCP-generated A record, change the Mac hostname, or turn off DHCP DNS updates.

On shutdown, the service removes only this Nix-managed app's DLL, dependency manifest, and configuration. A restart reinstalls them. Rolling back the Nix service therefore removes the extension while preserving every other Technitium app, lease, and zone.
