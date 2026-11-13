# Desktop and appearance

Separate application functionality, shared appearance, and desktop-session behavior by ownership.

## Boundaries

- Application scopes own installation, profiles, functional settings, and application-specific integrations.
- The theme scope owns common colors, typography, assets, and visual choices, including an application's appearance when that policy is shared.
- Desktop and compositor scopes own sessions, window management, focus, keybindings, and other desktop behavior.
- Overlays own packaging and compatibility patches, including patches necessary for an appearance feature.

Apply shared appearance to consumers through the existing cross-scope edit mechanism instead of duplicating styles in each application. Keep platform-specific visuals within the platforms that support them. Avoid installing or enabling an application through competing scopes.

## Native integration and runtime ownership

Prefer established XDG/freedesktop, desktop-environment, and application APIs for notifications, media, networking, Bluetooth, clipboard, portals, session state, and calendar integration. A desktop frontend should display and control system-managed state, not silently become another owner of that state. Use a custom bridge or helper only when a required capability is missing from the supported native interface, and keep that bridge narrow.

Prefer event-driven updates and on-demand queries over unconditional polling, duplicate background processes, or custom caches of authoritative external state. Handle late-starting and restarting services, timeouts, and offline cases without blocking the desktop or eagerly starting expensive work in inactive views. Performance and reliability are interface requirements, not merely visual details.

## Defaults and behavior

Prefer native application modules and defaults. Preserve declarations that affect profiles, session integration, or enablement even if their apparent settings move elsewhere.

Reusable application choices belong to shared policy inputs; shortcuts and integrations should consume those inputs rather than hard-code an executable.

## Verification

Compare effective settings and host derivations when changing ownership without intended behavior changes. For visual or interactive changes, validate rendered appearance, focus, keyboard navigation, animation, responsiveness, icons and labeling consistency, and accessibility on representative target clients. Nix evaluation cannot establish interactive behavior.
