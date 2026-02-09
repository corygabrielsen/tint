# tint

Terminal background color picker with live preview.

```
  ←/→ Navigate   Enter: Select   Esc: Cancel
  ████████  dracula      #282a36   [3/29] *
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
tint dracula          # Set by name
tint "#282a36"        # Set by hex
tint random           # Pick a random color
tint --reset          # Reset to terminal default
tint --query          # Query current background
tint --list           # List available colors
```

### Interactive Controls

| Key | Action |
|-----|--------|
| `←` `→` `h` `l` | Navigate colors |
| `↑` `↓` `k` `j` | Navigate colors |
| `Enter` | Select color |
| `Esc` `q` | Cancel (restore original) |

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

tint_query              # Query current background → #rrggbb
tint_set "#282a36"      # Set background
tint_reset              # Reset to default
tint_resolve "dracula"  # Resolve name → #282a36
tint_lookup "dracula"   # Look up in palette → #282a36
tint_list               # Print all palette entries
tint_pick "$current"    # Interactive picker → selected hex
```

## Shell Integration

Auto-apply colors per directory (reads `.tint` file):

```bash
# Add to ~/.bashrc or ~/.zshrc
tint_auto() { [[ -f .tint ]] && tint "$(cat .tint)"; }
cd() { builtin cd "$@" && tint_auto; }
```

Then create `.tint` files in project directories:

```bash
echo "dracula" > ~/projects/myproject/.tint
```

## Compatibility

| Feature | Requirement |
|---------|-------------|
| Interactive picker (`tint`) | Bash 3.2+ |
| All other commands | Any POSIX shell (dash, ash, sh) |
| Terminal | OSC 11 support (most modern terminals) |

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
