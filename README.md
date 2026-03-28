# tint

[![CI](https://github.com/corygabrielsen/tint/actions/workflows/ci.yml/badge.svg)](https://github.com/corygabrielsen/tint/actions/workflows/ci.yml)
[![Latest Release](https://img.shields.io/github/v/release/corygabrielsen/tint)](https://github.com/corygabrielsen/tint/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Terminal theme switcher with live preview. Each theme sets background, foreground, and all 16 ANSI colors. Drop `.tint` files into project directories and your theme changes automatically as you navigate.

```
  ↑/↓ Navigate   Enter: Select   Esc: Cancel
*  1.  (unchanged)
>  2.  dracula
   3.  gruvbox
   ↓ 16 more
```

## Install

### Homebrew

```bash
brew install corygabrielsen/tint/tint
```

### Manual

```bash
curl -fsSL https://github.com/corygabrielsen/tint/releases/latest/download/tint \
  -o ~/.local/bin/tint && chmod +x ~/.local/bin/tint
```

Make sure `~/.local/bin` is in your `PATH`.

Verify:

```bash
tint --version
```

## Usage

```bash
tint                  # Interactive picker with live preview
tint dracula          # Set by name (bg + fg + 16 ANSI colors)
tint "#002b36"        # Set by hex (bg + auto-computed fg)
tint random           # Pick a random theme
tint reset            # Reset to terminal default
tint hook bash        # Output shell hook for auto-tinting on cd
tint completions bash # Output shell completions
tint -h, --help       # Show help
tint -l, --list       # List available themes
tint -v, --version    # Show version
```

### Interactive Controls

| Key             | Action                    |
| --------------- | ------------------------- |
| `↑` `↓` `k` `j` | Navigate list             |
| `←` `→` `h` `l` | Navigate list (alternate) |
| `Enter`         | Select theme              |
| `Esc` `q`       | Cancel (restore original) |

## Built-in Themes

**Dark:**
`ayu` `campbell` `catppuccin-frappe` `catppuccin-macchiato` `catppuccin-mocha`
`cobalt` `dracula` `everforest-dark` `github` `gruvbox-dark` `horizon`
`kanagawa` `material` `monokai` `night-owl` `nord` `onedark` `palenight`
`rose-pine` `rose-pine-moon` `solarized-dark` `synthwave` `tango` `tokyo`

**Light:**
`catppuccin-latte` `everforest-light` `gruvbox-light` `onelight`
`rose-pine-dawn` `solarized-light`

## Custom Palette

Each theme is a name followed by 18 hex colors: background, foreground, and ANSI colors 0-15.

```
name:#bg:#fg:#00:#01:#02:#03:#04:#05:#06:#07:#08:#09:#10:#11:#12:#13:#14:#15
```

Create a palette file at `~/.config/tint/palette.conf`:

```
mytheme:#1a1b26:#c0caf5:#414868:#f7768e:#9ece6a:#e0af68:#7aa2f7:#bb9af7:#7dcfff:#a9b1d6:#414868:#f7768e:#9ece6a:#e0af68:#7aa2f7:#bb9af7:#7dcfff:#c0caf5
```

Then:

```bash
export TINT_PALETTE_FILE=~/.config/tint/palette.conf
tint
```

Or inline:

```bash
export TINT_PALETTE='mytheme:#1a1b26:#c0caf5:#414868:#f7768e:#9ece6a:#e0af68:#7aa2f7:#bb9af7:#7dcfff:#a9b1d6:#414868:#f7768e:#9ece6a:#e0af68:#7aa2f7:#bb9af7:#7dcfff:#c0caf5'
tint
```

## Library Usage

Source `tint` to use its functions in scripts:

```bash
source /path/to/tint

tint_supports_color       # Check if terminal supports OSC color sequences
tint_resolve "dracula"    # Name → full theme string, hex → expanded #rrggbb
tint_lookup "dracula"     # Palette name → theme string (#bg:#fg:#00:...:#15)
tint_set "#002b36"        # Set background (auto-computes foreground)
tint_set "$theme_string"  # Set full theme (bg + fg + 16 ANSI colors)
tint_reset                # Reset to terminal default
tint_pick "$current"      # Interactive picker → selected theme name
tint_list                 # Print all theme names
```

## Shell Integration

Auto-apply terminal themes when you `cd` into a project. The hook runs on every directory change — your terminal shifts to match whatever you're working on.

```bash
# bash (~/.bashrc)
eval "$(tint hook bash)"

# zsh (~/.zshrc)
eval "$(tint hook zsh)"
```

Then create `.tint` files in project directories:

```bash
echo "nord" > ~/projects/myproject/.tint
echo "dracula" > ~/projects/work/.tint
echo "reset" > ~/projects/personal/.tint    # reset to default
```

The hook walks up from `$PWD` to `/` looking for the nearest `.tint` file. Themes are **sticky** — if no `.tint` is found, the current theme is kept. Place a `.tint` in `~` for a global default.

A `.tint` file contains a single value — either a theme name (`dracula`), hex (`#002b36`), or `reset`. Inline comments are supported (`dracula # work theme`).

Fish shell is not currently supported for hooks (completions work via `tint completions fish`).

For tab completion of theme names and subcommands, see [Shell Completions](#shell-completions).

## Shell Completions

Tab-complete theme names, subcommands, and flags:

```bash
# bash (~/.bashrc)
eval "$(tint completions bash)"

# zsh (~/.zshrc)
eval "$(tint completions zsh)"

# fish
tint completions fish > ~/.config/fish/completions/tint.fish
```

## Compatibility

| Feature                     | Requirement                                 |
| --------------------------- | ------------------------------------------- |
| Interactive picker (`tint`) | Bash 3.2+                                   |
| All other commands          | Any POSIX shell (dash, ash, sh)             |
| Terminal                    | OSC 4/10/11 support (most modern terminals) |

Tested on: iTerm2, Alacritty, Kitty, Windows Terminal, GNOME Terminal, Konsole

**tmux**: Requires `set -g allow-passthrough on` in your tmux config for OSC sequences to reach the outer terminal.

## How It Works

`tint` uses [OSC escape sequences](https://invisible-island.net/xterm/ctlseqs/ctlseqs.html#h3-Operating-System-Commands) to control terminal colors:

- `\e]11;#rrggbb\e\\` — Set background color (OSC 11)
- `\e]10;#rrggbb\e\\` — Set foreground color (OSC 10)
- `\e]4;N;#rrggbb\e\\` — Set ANSI color N (OSC 4, N=0-15)
- `\e]11;?\e\\` — Query current background
- `\e]111\e\\` — Reset background to default
- `\e]110\e\\` — Reset foreground to default
- `\e]104\e\\` — Reset all ANSI colors to default

## Development

```bash
make setup    # Install pre-commit hooks and shellcheck
make doctor   # Check dev environment
make lint     # Run shellcheck
make test     # Run tests
```

## License

MIT
