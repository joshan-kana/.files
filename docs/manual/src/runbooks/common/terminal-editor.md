# Portable terminal editor

The terminal editing environment is available on macOS and Linux through the repository flake. It uses the same Neovim plugins, language tools, and shortcuts as the Home Manager configuration without requiring a system rebuild.

From a checkout of `.files`:

```sh
nix run .#editor -- path/to/file.nix
nix run .#terminal-editor
```

`editor` starts configured Neovim directly. `terminal-editor` starts a Zellij workspace with an editor pane, a tab bar, and a status bar. To make both commands available repeatedly in an interactive shell:

```sh
nix develop .#editor -c "$SHELL"
editor-nvim path/to/file.nix
terminal-editor
```

The standalone editor keeps its state under the `terminal-editor` Neovim application name. Home Manager-managed `nvim` uses the same editing setup but remains part of the normal user profile. Both use Nix-managed plugins and language servers; there is no runtime plugin download step.

## Keybindings

| Keys        | Action                                                   |
| ----------- | -------------------------------------------------------- |
| `Space f f` | Open file picker                                         |
| `Space f g` | Search project contents                                  |
| `Space f e` | Open explorer                                            |
| `Space f r` | Recent files                                             |
| `Space c s` | Symbols in the current file                              |
| `Space c g` | Go to definition                                         |
| `Space c R` | Find references                                          |
| `Space c a` | Code action                                              |
| `Space c f` | Format current buffer with Nix-provided formatter or LSP |
| `Space c D` | Diagnostics list                                         |
| `Space g s` | Git status                                               |
| `Space g j` | Open `jjui` within a Jujutsu workspace                   |
| `Space t t` | Toggle the integrated terminal                           |
| `Space e n` | Search available editor bindings                         |
| `Space e m` | Switch between positional and native Vim mappings        |
| `Space e s` | Toggle selection-first editing                           |
| `Space ?`   | Show available shortcuts                                 |

Neovim retains the standard `hjkl` movement keys. The positional profile adds `z` for undo and `x` for redo; the native profile restores Vim's original `z` and `x` behaviour. The optional selection-first layer works with either profile, adding `w`/`W` to select the next word and `S` to select a line. The operator-first `dw` command remains available in both.

The active editing profile is shown in the statusline. Use `:EditorKeymap native` for native Vim or `:EditorSelection on` to enable selection-first editing directly.

## Zellij key capture

The editor workspace starts Zellij in **Locked** mode, leaving Neovim's keys available without interception. Press `Ctrl+g` to enter Zellij's normal control mode. There, the ordinary Zellij pane/tab shortcuts are available; press `Ctrl+g` again to return to the editor's keyboard control. The same default mode is used for the Home Manager-managed Zellij configuration.

Open the editor on the remote machine when connecting over SSH, so language servers, file paths, and Jujutsu operate on the remote workspace. The terminal client must support interactive full-screen programs and the configured symbols.

## Diagnostics

Language servers and formatting tools are provided through Nix, not downloaded by the editor. Explicit formatting is available through `:Format` and `Space c f`; saving a buffer does not silently reformat it. LSP attachment depends on filetype and the presence of a suitable project root. `:LspInfo`, `:checkhealth`, `:messages`, and `:EditorKeymap native` are useful first checks when a project or terminal environment behaves differently.
