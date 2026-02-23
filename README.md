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
tint --list           # List available colors
tint --names          # List names only
tint --query          # Query current background
```

### Interactive Controls

| Key             | Action                    |
| --------------- | ------------------------- |
| `↑` `↓` `k` `j` | Navigate list             |
| `←` `→` `h` `l` | Navigate list (alternate) |
| `Enter`         | Select color              |
| `Esc` `q`       | Cancel (restore original) |

## Available Colors

29 popular themes:

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
tint_query                # Query current background → #rrggbb
tint_resolve "solarized"  # Resolve name → #002b36
tint_lookup "solarized"   # Look up in palette → #002b36
tint_set "#002b36"        # Set background
tint_reset                # Reset to default
tint_pick "$current"      # Interactive picker → selected hex
tint_list                 # Print all palette entries
tint_list_names           # Print color names only
```

## Shell Integration

Auto-apply colors per directory using `.tint` files:

```bash
# bash (~/.bashrc)
eval "$(tint hook bash)"

# zsh (~/.zshrc)
eval "$(tint hook zsh)"
```

Create `.tint` files in project directories:

```bash
echo "nord" > ~/projects/myproject/.tint
echo "solarized" > ~/projects/work/.tint
echo "reset" > ~/projects/personal/.tint    # reset to default
```

For tab completion of color names and subcommands, see [Shell Completions](#shell-completions).

The hook walks up from `$PWD` to `/` looking for the nearest `.tint` file. Colors are **sticky** — if no `.tint` is found, the current color is kept. Place a `.tint` in `~` for a global default.

A `.tint` file contains a single color (name or `#hex`):

```
solarized
```

or

```
#002b36
```

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

## How It Works

`tint` uses [OSC 11](https://invisible-island.net/xterm/ctlseqs/ctlseqs.html#h3-Operating-System-Commands) escape sequences:

- `\e]11;#rrggbb\e\\` - Set background color
- `\e]11;?\e\\` - Query current background
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
