# Desktop and appearance

**Convention:** The application owns installation and behavior; the theme owns shared visual policy; the desktop/compositor owns session and window-management behavior.

## Application and theme boundaries

- `modules/desktop-apps/` owns applications that are not intrinsically tied to one desktop environment: installation, profiles, program-specific functional settings, and native Home Manager integration.
- `modules/theme/` owns shared palette, assets, typography, and application chrome. Use `scopeEdits.desktopApps.<app>` to apply theme policy to an app rather than duplicating styling under each app scope.
- `scopeEdits.desktop.hyprland` is appropriate for **Hyprland-specific visual policy**, including GTK/GNOME window-button layout; gate this to Linux so Darwin and unrelated desktops remain unaffected.
- `modules/desktop/hyprland/` owns compositor sessions, keybindings, window-management behavior, and desktop integration that is not shared appearance policy.
- `overlays/` owns package patches, even when they address a visual compatibility issue. The chosen visual policy can still be described by the theme.

Avoid installing the same application in competing desktop and desktop-app modules.

## Native interface and defaults

Prefer native Home Manager application modules and defaults. Keep required application declarations, such as Firefox/Floorp profile activation and VS Code's default profile, even if their visual settings move into the theme. A seemingly empty declaration may affect evaluated enablement.

Central reusable program choices, such as the default browser executable, belong to `dotfiles.defaults.*` policy. A binding that launches the browser should consume that default, not hard-code a particular browser. Platform-specific MIME associations belong to the native environment.

## Validation

Evaluate the app's effective settings and enabled profiles, not just the moved Nix source. Confirm appearance values and host derivations remain unchanged for an ownership-only refactor. For visual changes, test actual rendering, animation, accessibility, focus, and keyboard interaction at supported display sizes and refresh rates.

Not all session behavior can be verified through Nix evaluation; interactive desktop testing remains necessary for such changes.
