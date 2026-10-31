# Neovim editing profiles

Use `Space e m` to switch between the positional and native Vim layouts, or run `:EditorKeymap positional` / `:EditorKeymap native`. The selection-first layer is independent: toggle it with `Space e s` or use `:EditorSelection on|off|toggle`.

Both preferences are restored when Neovim restarts. They are stored per machine in Neovim's local XDG state directory as `editor-profiles.json`, not in the repository. A new installation defaults to positional editing with selection-first disabled.

## Positional layout

The lowercase `h j k l` movement keys, insert-mode commands, operators and operator-pending motions remain native Vim. Positional editing changes the following normal-mode keys:

| Key | Action                   | Key | Action       |
| --- | ------------------------ | --- | ------------ |
| `z` | Undo                     | `x` | Redo         |
| `H` | First nonblank character | `L` | End of line  |
| `J` | Half-page down           | `K` | Half-page up |

Commands displaced by these shortcuts remain available:

| Shortcut                  | Action                                   | Shortcut                  | Action                  |
| ------------------------- | ---------------------------------------- | ------------------------- | ----------------------- |
| `Space e x` / `Space e X` | Delete character / delete backward       | `Space e j`               | Join lines              |
| `Space e k`               | Keyword help                             | `Space e h` / `Space e l` | Top / bottom of screen  |
| `Space e d` / `Space e y` | Delete / yank line                       | `Space e c`               | Change line             |
| `Space e p` / `Space e P` | Paste after / before                     | `Space e o` / `Space e O` | Open line below / above |
| `Space e i` / `Space e a` | Insert at first nonblank / append at end | `Space u c`               | Center current line     |
| `Space u t` / `Space u b` | Current line at top / bottom             | `Space u a`               | Toggle fold             |
| `Space u o` / `Space u C` | Open / close fold                        | `Space e u`               | Undo history picker     |

The native Vim layout removes positional mappings completely, including these alternate shortcuts, and restores the native meanings of `z`, `x`, `H`, `J`, `K` and `L`.

## Selection-first layer

When enabled, motion keys start a Visual selection in normal mode. Operate on the selection using Vim's Visual commands: `d` deletes, `c` changes, `y` yanks, `p` replaces, `r` replaces characters, and `>` / `<` change indentation. `Esc` cancels selection.

| Keys                                          | Selection                                     |
| --------------------------------------------- | --------------------------------------------- |
| `w` / `W`                                     | Word / WORD, including surrounding whitespace |
| `b` / `B`                                     | Backwards to word / WORD start                |
| `e` / `E`                                     | Forward to word / WORD end                    |
| `0` / `^` / `$`                               | Line start / first nonblank / line end        |
| `gg` / `G`                                    | File start / file end (or counted line)       |
| `(` / `)`                                     | Previous / next sentence                      |
| `{` / `}`                                     | Previous / next paragraph                     |
| `f` / `F` / `t` / `T` followed by a character | Character-find motions                        |
| `n` / `N`                                     | Next / previous search match                  |
| `S`                                           | Whole line                                    |
| `s` followed by a motion or text object       | Explicit Visual selection prefix              |

The prefix makes built-in text objects available without entering Visual mode manually: `siw` selects an inner word, `saw` an around-word, `si(` inside parentheses, `sa"` a quoted string including its quotes, `sip` a paragraph, and `s%` a matching-delimiter range. Counts work with direct selections such as `2wd`, and with character finds such as `2fXd`.

Native operator-pending commands are unchanged by the selection layer. `dw`, `d3w`, `ciw`, registers, macro playback and dot-repeat remain usable. The layer also works on top of native Vim, and disabling it restores the native normal-mode mappings.

`h j k l` are not remapped by the selection layer. Start an explicit selection with `s` and then use these keys to extend it.

## Command-line completion

When entering an Ex command such as `:EditorSelection`, suggestions appear automatically. Use `Up` / `Down` to navigate them, `Tab` to accept the selected suggestion without running the command, and `Enter` to execute. `Right` retains normal cursor movement. This does not change insert-mode code completion.

Key descriptions are also discoverable through `Space ?` and `Space e n`.
