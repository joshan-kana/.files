# Desktop and appearance

Separate application functionality, shared appearance, and desktop-session behavior by ownership.

## Boundaries

- Application scopes own installation, profiles, functional settings, and application-specific integrations.
- The theme scope owns common colors, typography, assets, and visual choices, including an application's appearance when that policy is shared.
- Desktop and compositor scopes own sessions, window management, focus, keybindings, and other desktop behavior.
- Overlays own packaging and compatibility patches, including patches necessary for an appearance feature.

Apply shared appearance to consumers through the existing cross-scope edit mechanism instead of duplicating styles in each application. Keep platform-specific visuals within the platforms that support them. Avoid installing or enabling an application through competing scopes.

## Defaults and behavior

Prefer native application modules and defaults. Preserve declarations that affect profiles, session integration, or enablement even if their apparent settings move elsewhere.

Reusable application choices belong to shared policy inputs; shortcuts and integrations should consume those inputs rather than hard-code an executable.

## Verification

Compare effective settings and host derivations when changing ownership without intended behavior changes. For visual or interactive changes, validate rendered appearance, focus, keyboard navigation, animation, responsiveness, and accessibility on representative target clients. Nix evaluation cannot establish interactive behavior.
