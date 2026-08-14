# gh-dash Projects v2 integration

The declarative CLI environment provides a patched `gh-dash` package as
`gh-dash-projects`. It keeps GitHub as the source of truth and adds Project v2
metadata to the existing issue and pull-request TUI.

Project field columns are opt-in in `~/.config/gh-dash/config.yml`:

```yaml
defaults:
  layout:
    projects:
      fields:
        - name: Status
          project: infrastructure
          width: 18
        - name: Priority
          width: 14
```

`name` is matched against the runtime Project field name. `project` is
optional and may be a Project title or number. Without it, values from all
matching memberships are shown in deterministic Project-title order and are
prefixed with their Project title, so equal field names do not silently
collide. A project-qualified column shows only that Project's value.

When an issue or pull request is selected, its Project memberships and
available values appear in the preview. Press `e` to choose a Project, choose a
field, and then choose a single-select option or enter a text/number/date/
iteration value. The mutation discovers Project and field IDs at runtime and
the successful value is applied to the in-memory row from GitHub's mutation
result; no local database or sync process is used. Users, labels, and
repository-related fields are display-only where GitHub does not provide a
safe generic editor flow.

The package is pinned to an upstream gh-dash commit and applied through the
repository's `overlays/gh-dash-projects.nix` overlay. Future upstream updates
should bump that commit, regenerate or refresh the downstream patch, run the
gh-dash tests, and rebuild the package before replacing the package pin.
