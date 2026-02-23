# tint

[![CI](https://github.com/corygabrielsen/tint/actions/workflows/ci.yml/badge.svg)](https://github.com/corygabrielsen/tint/actions/workflows/ci.yml)
[![Latest Release](https://img.shields.io/github/v/release/corygabrielsen/tint)](https://github.com/corygabrielsen/tint/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Terminal background color picker with live preview.

```
  ↑/↓ Navigate   Enter: Select   Esc: Cancel
*  1.    - - - -    (unchanged)
>  2.    #000000    black
   3.    #1e1e1e    vscode
   4.    #282a36    dracula
   ↓ 25 more
```

## Install

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
tint solarized        # Set by name
tint "#002b36"        # Set by hex
tint random           # Pick a random color
tint reset            # Reset to terminal default
tint completions bash # Output shell completions
tint -h, --help       # Show help
tint -l, --list       # List available colors
tint -g, --get        # Get current background color
tint -v, --version    # Show version
```

### Interactive Controls

| Key             | Action                    |
| --------------- | ------------------------- |
| `↑` `↓` `k` `j` | Navigate list             |
| `←` `→` `h` `l` | Navigate list (alternate) |
| `Enter`         | Select color              |
| `Esc` `q`       | Cancel (restore original) |

## Available Colors

Built-in themes:

```
vscode, dracula, nord, gruvbox, onedark, monokai, catppuccin, tokyo,
solarized, github, rose-pine, night-owl, ayu, black, cobalt, darcula,
everforest, forest, horizon, kanagawa, material, midnight, navy,
obsidian, oxblood, palenight, slate, synthwave, ubuntu
```

## Custom Palette

Create `~/.config/tint/palette.conf`:

```
# My custom colors
mycolor:#123456
another:#abcdef
```

Then:

```bash
export TINT_PALETTE_FILE=~/.config/tint/palette.conf
tint
```

Or inline:

```bash
export TINT_PALETTE=$'custom1:#111111\ncustom2:#222222'
tint
```

## Library Usage

Source `tint` to use its functions in scripts:

```bash
source /path/to/tint

tint_supports_color       # Check if terminal supports OSC colors
tint_get                  # Get current background → #rrggbb
tint_resolve "solarized"  # Name or hex → normalized #rrggbb
tint_lookup "solarized"   # Palette name → #rrggbb (exact match)
tint_set "#002b36"        # Set background
tint_reset                # Reset to default
tint_pick "$current"      # Interactive picker → selected hex
tint_list                 # Print all palette entries
```

## Shell Integration

Auto-apply terminal colors when you `cd` into a project. The hook runs on every directory change — your terminal shifts to match whatever you're working on.

```bash
# bash (~/.bashrc)
eval "$(tint hook bash)"

# zsh (~/.zshrc)
eval "$(tint hook zsh)"
```

Then create `.tint` files in project directories:

```bash
echo "nord" > ~/projects/myproject/.tint
echo "solarized" > ~/projects/work/.tint
echo "reset" > ~/projects/personal/.tint    # reset to default
```

The hook walks up from `$PWD` to `/` looking for the nearest `.tint` file. Colors are **sticky** — if no `.tint` is found, the current color is kept. Place a `.tint` in `~` for a global default.

A `.tint` file contains a single color — either a name (`solarized`) or hex (`#002b36`).

Fish shell is not currently supported for hooks (completions work via `tint completions fish`).

For tab completion of color names and subcommands, see [Shell Completions](#shell-completions).

## Shell Completions

Tab-complete color names, subcommands, and flags:

```bash
# bash (~/.bashrc)
eval "$(tint completions bash)"

# zsh (~/.zshrc)
eval "$(tint completions zsh)"

# fish
tint completions fish > ~/.config/fish/completions/tint.fish
```

## Compatibility

| Feature                     | Requirement                            |
| --------------------------- | -------------------------------------- |
| Interactive picker (`tint`) | Bash 3.2+                              |
| All other commands          | Any POSIX shell (dash, ash, sh)        |
| Terminal                    | OSC 11 support (most modern terminals) |

Tested on: iTerm2, Alacritty, Kitty, Windows Terminal, GNOME Terminal, Konsole

**tmux**: Requires `set -g allow-passthrough on` in your tmux config for OSC 11 sequences to reach the outer terminal.

**`--get` / `tint_get`**: Relies on the terminal responding to an OSC 11 query within 200ms. This works reliably on local and most remote terminals, but may time out on very slow SSH connections or terminals that don't support the query.

## How It Works

`tint` uses [OSC 11](https://invisible-island.net/xterm/ctlseqs/ctlseqs.html#h3-Operating-System-Commands) escape sequences:

- `\e]11;#rrggbb\e\\` - Set background color
- `\e]11;?\e\\` - Get current background
- `\e]111\e\\` - Reset to default

## Development

```bash
make setup    # Install pre-commit hooks and shellcheck
make doctor   # Check dev environment
make lint     # Run shellcheck
make test     # Run tests
```

## License

MIT
