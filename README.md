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

Requires `awk` (for palette parsing) and a terminal that supports OSC 11 background-color sequences. Both are standard on modern systems.

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

### Curated (33)

Chosen from popular community themes.

**Dark:** `apprentice` `ayu` `campbell` `catppuccin-frappe` `catppuccin-macchiato` `catppuccin-mocha` `cobalt2` `dracula` `everforest-dark` `github` `gruvbox-dark` `horizon` `kanagawa` `linux-console` `material` `monokai` `night-owl` `nord` `onedark` `palenight` `putty` `rose-pine` `rose-pine-moon` `solarized-dark` `synthwave` `tango` `tokyo`

**Light:** `catppuccin-latte` `everforest-light` `gruvbox-light` `onelight` `rose-pine-dawn` `solarized-light`

### Rainbow Wheel (144)

24 hues × 6 lightness/saturation tiers. Hue order: red, vermilion, orange, amber, yellow, lime, chartreuse, harlequin, green, emerald, spring-green, aquamarine, cyan, sky-blue, azure, cobalt, blue, indigo, violet, purple, magenta, fuchsia, rose, crimson.

**Deep** (L=0.20, S=0.35 — near-black with strong hue): `deep-red` `deep-vermilion` `deep-orange` `deep-amber` `deep-yellow` `deep-lime` `deep-chartreuse` `deep-harlequin` `deep-green` `deep-emerald` `deep-spring-green` `deep-aquamarine` `deep-cyan` `deep-sky-blue` `deep-azure` `deep-cobalt` `deep-blue` `deep-indigo` `deep-violet` `deep-purple` `deep-magenta` `deep-fuchsia` `deep-rose` `deep-crimson`

**Dark** (L=0.35, S=0.35 — between deep and base): `dark-red` `dark-vermilion` `dark-orange` `dark-amber` `dark-yellow` `dark-lime` `dark-chartreuse` `dark-harlequin` `dark-green` `dark-emerald` `dark-spring-green` `dark-aquamarine` `dark-cyan` `dark-sky-blue` `dark-azure` `dark-cobalt` `dark-blue` `dark-indigo` `dark-violet` `dark-purple` `dark-magenta` `dark-fuchsia` `dark-rose` `dark-crimson`

**Muted** (L=0.50, S=0.35 — base canonical hue, no prefix): `red` `vermilion` `orange` `amber` `yellow` `lime` `chartreuse` `harlequin` `green` `emerald` `spring-green` `aquamarine` `cyan` `sky-blue` `azure` `cobalt` `blue` `indigo` `violet` `purple` `magenta` `fuchsia` `rose` `crimson`

**Light** (L=0.65, S=0.35 — lighter hue, dark text required): `light-red` `light-vermilion` `light-orange` `light-amber` `light-yellow` `light-lime` `light-chartreuse` `light-harlequin` `light-green` `light-emerald` `light-spring-green` `light-aquamarine` `light-cyan` `light-sky-blue` `light-azure` `light-cobalt` `light-blue` `light-indigo` `light-violet` `light-purple` `light-magenta` `light-fuchsia` `light-rose` `light-crimson`

**Pale** (L=0.80, S=0.35 — pastel daytime, dark text required): `pale-red` `pale-vermilion` `pale-orange` `pale-amber` `pale-yellow` `pale-lime` `pale-chartreuse` `pale-harlequin` `pale-green` `pale-emerald` `pale-spring-green` `pale-aquamarine` `pale-cyan` `pale-sky-blue` `pale-azure` `pale-cobalt` `pale-blue` `pale-indigo` `pale-violet` `pale-purple` `pale-magenta` `pale-fuchsia` `pale-rose` `pale-crimson`

**Neon** (L=0.50, S=0.80 — high-saturation siblings of muted): `neon-red` `neon-vermilion` `neon-orange` `neon-amber` `neon-yellow` `neon-lime` `neon-chartreuse` `neon-harlequin` `neon-green` `neon-emerald` `neon-spring-green` `neon-aquamarine` `neon-cyan` `neon-sky-blue` `neon-azure` `neon-cobalt` `neon-blue` `neon-indigo` `neon-violet` `neon-purple` `neon-magenta` `neon-fuchsia` `neon-rose` `neon-crimson`

## Custom Palette

Each theme is a name followed by 18 hex colors: background, foreground, and ANSI colors 0-15.

```
name:#bg:#fg:#00:#01:#02:#03:#04:#05:#06:#07:#08:#09:#10:#11:#12:#13:#14:#15
```

Drop theme files into `$XDG_CONFIG_HOME/tint/themes` (commonly `~/.config/tint/themes` when `XDG_CONFIG_HOME` is unset; any filename works):

```bash
mkdir -p ~/.config/tint/themes
cat > ~/.config/tint/themes/mine.theme <<'EOF'
mytheme:#1a1b26:#c0caf5:#414868:#f7768e:#9ece6a:#e0af68:#7aa2f7:#bb9af7:#7dcfff:#a9b1d6:#414868:#f7768e:#9ece6a:#e0af68:#7aa2f7:#bb9af7:#7dcfff:#c0caf5
EOF
tint mytheme
```

Each file can contain one or more theme entries, one per line. Files are read in alphabetical order and appended to the built-in palette. Pick unique names for your drop-in themes — built-ins win lookups on name collision. Set `TINT_PALETTE_DIR` to override the `$XDG_CONFIG_HOME/tint/themes` default.

## Library Usage

Source `tint` to use its functions in scripts. Use `.` for POSIX compatibility, or `source` in bash/zsh:

```bash
. /path/to/tint

tint_supports_color       # Check if terminal supports OSC color sequences
tint_resolve "dracula"    # Name → full theme string, hex → expanded #rrggbb
tint_lookup "dracula"     # Palette name → theme string (#bg:#fg:#00:...:#15)
tint_set "#002b36"        # Set background (auto-computes foreground)
tint_set "$theme_string"  # Set full theme (bg + fg + 16 ANSI colors)
tint_reset                # Reset to terminal default
tint_pick "$current"      # Interactive picker → selected theme name
tint_list                 # Print all theme names
tint_reload_palette       # Rebuild TINT_PALETTE after changing TINT_PALETTE_DIR / XDG_CONFIG_HOME / HOME
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
