# Haven

Haven provides a private, account-aware interface for everyday home controls, media activity, and launching household applications. Home Assistant and the media managers remain authoritative for their own state and permissions.

## Service and storage

The NixOS module owns the application package, restricted systemd service, private ingress, certificate credentials, and writable state directory. The application runs under a dedicated unprivileged account and listens on loopback behind Nginx.

The state directory is supplied through `DASHBOARD_DATA_DIR`. It contains:

- `users.json`: local account configuration, password hashes, personal dashboard preferences, and encrypted upstream credentials.
- `master.key`: the encryption key needed to recover those upstream credentials.
- `setup-token`: a one-time first-run enrollment token, removed after the administrator account is created.

Preserve the state directory and the master key together. Restoring `users.json` without its matching `master.key` makes saved integration credentials unreadable. Do not place any of these files in the Nix store, Git, logs, or shared artifacts.

## First-run enrollment

On first launch, Haven creates a one-time setup token in its protected state directory. A server administrator reads that file locally and enters the token and a new administrator password into the first-run page over the private HTTPS endpoint. The token is consumed once the account is created.

Administrators can create, disable, and manage individual Haven accounts and page permissions. Each person connects their own Home Assistant, Sonarr, and Radarr credentials in Settings. Credentials are encrypted server-side, never sent back to browsers, and do not grant greater access than the corresponding upstream account.

## Application shortcuts

The NixOS service passes a list of enabled applications into Haven from the resolved declarative scopes and service options. Haven only lists those enabled applications that the signed-in account is permitted to access; a disabled service is not offered as a launcher. The application retains a small set of known service names, destinations, and categories rather than probing private interfaces.

Each account can pin applications in the launcher. Pinned applications appear first on the Applications page and in the Overview, followed by frequently opened applications. Launch counts and pinned application IDs are persisted alongside that account's other preferences and are not shared with other accounts.

## Live updates

Home Assistant supplies state snapshots, state changes, and registry updates via an authenticated WebSocket subscription. Haven reconstructs entity state and exposes permission-filtered events to connected browsers.

Sonarr and Radarr use authenticated SignalR connections. The initial queue is read after subscription establishment, and subsequent notifications trigger coalesced targeted queue reads. There are no recurring background state-fetch intervals.

Upstream connections are shared among active browser tabs for the **same Haven account, session version, service, and encrypted credential**. Another account always uses its own upstream authorization. A closed or revoked session cannot continue receiving events. The final subscriber closes the shared upstream connection.

If an integration is offline, Haven displays its connection state and reconnects with a fresh snapshot. Where a source does not support push notifications, the interface must label explicitly retrieved data rather than presenting it as live.

## Recovery and validation

A manual password reset requires stopping the Haven service, invoking the packaged `home-dashboard reset-password` command as the service owner with the replacement password on standard input, and restarting the service. Password-reset operations revoke existing sessions through the account version.

Restoration of an application-state backup should occur with Haven stopped and the previous state preserved until the restored instance has been validated. NixOS generation rollback and restoration of mutable account data are separate operations.

Relevant checks include the Go test suite and race detector, the repository's Nix quality and package checks, and the automated browser simulator in `tests/browser-smoke.mjs`. The simulator uses synthetic entities and media events; it does not operate real devices. Use a current Node.js runtime and Chromium or Chrome. `CHROME_BIN` can specify the browser executable.

Validate the deployed HTTPS event stream separately from the local simulator, because reverse-proxy buffering and authentication can affect streaming even when unit tests pass.
