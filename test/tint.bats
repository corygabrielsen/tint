#!/usr/bin/env bats
# shellcheck disable=SC1091,SC2030,SC2031,SC2034

setup() {
    DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    PATH="$DIR:$PATH"
    # Default isolation: tests assume only the built-in palette is present.
    # Tests that exercise the drop-in dir must override TINT_PALETTE_DIR
    # explicitly (typically via _load_tint_with_themes).
    export TINT_PALETTE_DIR=/nonexistent-tint-test-dir
    # Filler suffix for drop-in themes — fg + 16 ANSI slots. Drop-in tests
    # prepend `name:#bg` and don't assert on the suffix values.
    ANSI16=':#112233:#000000:#111111:#222222:#333333:#444444:#555555:#666666:#777777:#888888:#999999:#aaaaaa:#bbbbbb:#cccccc:#dddddd:#eeeeee:#ffffff'
    _setup_picker_constants
}

# Helper to source the library within a test (BATS runs tests in subshells)
_load_tint() {
    source "$DIR/tint"
}

# Source tint with TINT_PALETTE_DIR pointing at a temp dir populated with
# the given (filename, content) pairs. Cleans up the tmpdir afterward.
_load_tint_with_themes() {
    local tmpdir
    tmpdir=$(mktemp -d)
    while [ $# -ge 2 ]; do
        printf '%s\n' "$2" > "$tmpdir/$1"
        shift 2
    done
    TINT_PALETTE_DIR="$tmpdir" source "$DIR/tint"
    rm -rf "$tmpdir"
}

# Assert that a relative value in $var causes its theme dir to be ignored.
# Plants a "shouldnotload" theme at $subpath (relative to a tmp cwd) and
# verifies it doesn't appear in TINT_PALETTE. Higher-priority env vars are
# unset so the var under test is the active config source.
_assert_relative_path_ignored() {
    local var="$1" val="$2" subpath="$3"
    # Subshell: cd and exports can't leak to the test process; rm -rf
    # can't leave the caller in a deleted CWD.
    (
        local fakethemes
        fakethemes=$(mktemp -d)
        mkdir -p "$fakethemes/$subpath"
        echo "shouldnotload:#abcdef${ANSI16}" > "$fakethemes/$subpath/x.theme"
        cd "$fakethemes" || return 1
        # Neutralize the full XDG/HOME fallback chain so only $var under
        # test is an active config source. Otherwise a real
        # ~/.config/tint/themes on the dev machine could leak in.
        unset TINT_PALETTE_DIR XDG_CONFIG_HOME
        export HOME=/nonexistent-tint-test-home
        # shellcheck disable=SC2163
        export "$var=$val"
        source "$DIR/tint"
        rm -rf "$fakethemes"
        [[ ! "$TINT_PALETTE" =~ "shouldnotload:" ]]
    )
}

# Derive palette constants so picker tests don't hardcode theme names or counts.
# Only the "palette has expected themes" snapshot test should need updating when
# themes are added, removed, or reordered.
_setup_picker_constants() {
    source "$DIR/tint"
    local count
    count=$(_tint_palette_count)

    THEME_FIRST=$(_tint_palette_get 1 | cut -d: -f1)
    THEME_SECOND=$(_tint_palette_get 2 | cut -d: -f1)
    THEME_THIRD=$(_tint_palette_get 3 | cut -d: -f1)
    THEME_LAST=$(_tint_palette_get "$count" | cut -d: -f1)
    THEME_SECOND_LAST=$(_tint_palette_get $((count - 1)) | cut -d: -f1)
    THEME_THIRD_LAST=$(_tint_palette_get $((count - 2)) | cut -d: -f1)

    PALETTE_COUNT=$count
    ITEM_COUNT=$((count + 1))  # themes + "unchanged" at idx 0
}

# =============================================================================
# CLI
# =============================================================================

@test "tint --help shows usage" {
    run tint --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "terminal theme switcher" ]]
}

@test "tint --version shows version" {
    run tint --version
    [ "$status" -eq 0 ]
    [[ "$output" =~ "tint" ]]
}

@test "tint --list shows themes" {
    run tint --list
    [ "$status" -eq 0 ]
    grep -q '^solarized-dark$' <<<"$output"
    grep -q '^dracula$' <<<"$output"
}

@test "tint -h matches --help" {
    run tint -h
    [ "$status" -eq 0 ]
    local short="$output"
    run tint --help
    [ "$status" -eq 0 ]
    [ "$short" = "$output" ]
}

@test "tint -l matches --list" {
    run tint -l
    [ "$status" -eq 0 ]
    local short="$output"
    run tint --list
    [ "$status" -eq 0 ]
    [ "$short" = "$output" ]
}

@test "tint -v matches --version" {
    run tint -v
    [ "$status" -eq 0 ]
    local short="$output"
    run tint --version
    [ "$status" -eq 0 ]
    [ "$short" = "$output" ]
}

@test "tint completions bash outputs bash completion" {
    run tint completions bash
    [ "$status" -eq 0 ]
    [[ "$output" =~ "complete -F" ]]
    [[ "$output" =~ "_tint_completions" ]]
}

@test "tint completions zsh outputs zsh completion" {
    run tint completions zsh
    [ "$status" -eq 0 ]
    [[ "$output" =~ "#compdef tint" ]]
    [[ "$output" =~ "compdef _tint tint" ]]
}

@test "tint completions fish outputs fish completion" {
    run tint completions fish
    [ "$status" -eq 0 ]
    [[ "$output" =~ "complete -c tint" ]]
}

@test "tint completions unknown fails" {
    run tint completions powershell
    [ "$status" -eq 1 ]
    [[ "$output" =~ "error: unknown shell" ]]
}

@test "tint completions defaults to bash" {
    run tint completions
    [ "$status" -eq 0 ]
    [[ "$output" =~ "complete -F" ]]
}

@test "bash completions include all subcommands" {
    run tint completions bash
    [ "$status" -eq 0 ]
    [[ "$output" =~ "completions" ]]
    [[ "$output" =~ "hook" ]]
    [[ "$output" =~ "reset" ]]
}

@test "zsh completions include all subcommands" {
    run tint completions zsh
    [ "$status" -eq 0 ]
    [[ "$output" =~ "completions" ]]
    [[ "$output" =~ "hook" ]]
    [[ "$output" =~ "reset" ]]
}

@test "fish completions include all subcommands" {
    run tint completions fish
    [ "$status" -eq 0 ]
    [[ "$output" =~ "completions" ]]
    [[ "$output" =~ "hook" ]]
    [[ "$output" =~ "reset" ]]
}

@test "tint random picks a palette theme" {
    run tint random
    [ "$status" -eq 0 ]
    # Output should be a theme name (2+ chars — all built-in names qualify;
    # the palette grammar allows 1-char names but none exist in practice)
    [[ "$output" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]+$ ]]
}

@test "tint unknown-theme fails" {
    run tint nonexistent
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Unknown theme" ]]
}

@test "tint unknown-option fails" {
    run tint --badoption
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Unknown option" ]]
}

@test "tint works via differently-named symlink" {
    # _tint_is_main's POSIX fallback checks the script content (grep for the
    # unique header URL) rather than the filename, so symlinks and renamed
    # copies are recognized as tint and correctly enter _tint_main.
    tmpdir=$(mktemp -d)
    ln -s "$DIR/tint" "$tmpdir/my-bg-picker"
    run "$tmpdir/my-bg-picker" --version
    rm -rf "$tmpdir"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "tint" ]]
}

# =============================================================================
# Sourcing
# =============================================================================

@test "tint sourced from POSIX script does not re-exec caller" {
    # When sourced from a #!/bin/sh script, $0 is the calling script, not
    # a shell. The POSIX fallback must not treat the caller as an executed
    # tint invocation — only the tint script itself contains the header URL.
    tmpdir=$(mktemp -d)
    cat > "$tmpdir/caller.sh" << INNEREOF
#!/bin/sh
echo "pre_source"
. "$DIR/tint"
echo "post_source"
echo "lookup=\$(tint_lookup solarized-dark)"
INNEREOF
    chmod +x "$tmpdir/caller.sh"
    run "$tmpdir/caller.sh"
    rm -rf "$tmpdir"
    [ "$status" -eq 0 ]
    # "pre_source" should appear exactly once (not re-exec'd)
    local count
    count=$(echo "$output" | grep -c "pre_source")
    [ "$count" -eq 1 ]
    [[ "$output" =~ "lookup=#002b36:" ]]
}

@test "tint sourced from script containing TINT_VERSION does not run main" {
    # A caller script that happens to have TINT_VERSION=foo in it
    # should not trigger _tint_main when sourcing tint.
    tmpdir=$(mktemp -d)
    cat > "$tmpdir/caller.sh" << INNEREOF
#!/bin/sh
TINT_VERSION=foo
echo "caller_only"
. "$DIR/tint"
echo "lookup=\$(tint_lookup solarized-dark)"
INNEREOF
    chmod +x "$tmpdir/caller.sh"
    run "$tmpdir/caller.sh" --version
    rm -rf "$tmpdir"
    [ "$status" -eq 0 ]
    # Should see caller output, NOT tint version info
    [[ "$output" =~ "caller_only" ]]
    [[ ! "$output" =~ "tint " ]]
    [[ "$output" =~ "lookup=#002b36:" ]]
}

@test "_tint_is_main guards BASH_SOURCE array access" {
    # BASH_SOURCE[0] is bash-only array syntax. In dash, [0] causes
    # "Bad substitution". The guard must use a subshell test to prevent
    # this even when BASH_VERSION leaks through the environment.
    grep -qE 'eval.*BASH_SOURCE\[0\]' "$DIR/tint" || {
        echo "_tint_is_main does not guard BASH_SOURCE array with eval"
        return 1
    }

    # Verify dash doesn't choke on _tint_is_main when BASH_SOURCE is unset
    run dash -c "
        . '$DIR/tint'
        echo 'sourced ok'
    "
    [ "$status" -eq 0 ]
    [[ "$output" =~ "sourced ok" ]]

    # Verify dash doesn't crash when BASH_VERSION leaks via environment
    run env BASH_VERSION=5 BASH_SOURCE=x dash -c "
        . '$DIR/tint'
        echo 'spoofed ok'
    "
    [ "$status" -eq 0 ]
    [[ "$output" =~ "spoofed ok" ]]
}

# =============================================================================
# Library API
# =============================================================================

@test "tint_lookup finds theme" {
    # Source directly - sourcing via function scopes variables to that function
    source "$DIR/tint"
    local result
    result=$(tint_lookup "solarized-dark")
    # Returns full theme string: #bg:#fg:#00:...:#15
    [[ "$result" == "#002b36:#839496:#073642:"* ]]
}

@test "tint_lookup fails for unknown" {
    _load_tint
    run tint_lookup "nonexistent"
    [ "$status" -eq 1 ]
}

@test "tint_lookup rejects glob metacharacters" {
    # case pattern is quoted ("$name:"*) so globs in input match literally.
    # d* must NOT match dracula, ay? must NOT match ayu, etc.
    source "$DIR/tint"
    run tint_lookup 'd*'
    [ "$status" -eq 1 ]
    run tint_lookup '*'
    [ "$status" -eq 1 ]
    run tint_lookup 'ay?'
    [ "$status" -eq 1 ]
    run tint_lookup '[a-z]yu'
    [ "$status" -eq 1 ]
}

@test "tint_resolve handles hex" {
    _load_tint
    run tint_resolve "#123456"
    [ "$status" -eq 0 ]
    [ "$output" = "#123456" ]
}

@test "tint_resolve handles name" {
    # Source directly - sourcing via function scopes variables to that function
    source "$DIR/tint"
    local result
    result=$(tint_resolve "dracula")
    # tint_resolve returns full theme string for named lookups
    [[ "$result" == "#282a36:#f8f8f2:#262626:"* ]]
}

@test "tint reset echoes 'reset'" {
    # OSC sequences go to /dev/tty; tested separately in "type tint_reset".
    source "$DIR/tint"
    run bash -c "
        source '$DIR/tint'
        tint reset
    "
    [ "$status" -eq 0 ]
    [ "$output" = "reset" ]
}

@test "tint_resolve handles reset" {
    _load_tint
    run tint_resolve "reset"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "tint_resolve fails for invalid" {
    _load_tint
    run tint_resolve "not-a-color"
    [ "$status" -eq 1 ]
}

@test "tint_resolve expands 3-digit hex" {
    _load_tint
    run tint_resolve "#abc"
    [ "$status" -eq 0 ]
    [ "$output" = "#aabbcc" ]
}

@test "tint_resolve expands 3-digit hex uppercase" {
    _load_tint
    run tint_resolve "#F0A"
    [ "$status" -eq 0 ]
    [ "$output" = "#FF00AA" ]
}

@test "tint_resolve rejects invalid hex" {
    _load_tint
    run tint_resolve "#12345"  # 5 digits
    [ "$status" -eq 1 ]
}

# =============================================================================
# Foreground Color
# =============================================================================

@test "_tint_fg_for_bg returns black for light bg" {
    source "$DIR/tint"
    local result
    result=$(_tint_fg_for_bg "#ffffff")
    [ "$result" = "#000000" ]
}

@test "_tint_fg_for_bg returns white for dark bg" {
    source "$DIR/tint"
    local result
    result=$(_tint_fg_for_bg "#000000")
    [ "$result" = "#ffffff" ]
}

@test "_tint_fg_for_bg boundary at luma 128" {
    # RGB (0, 0, 219) → luma = (0*299 + 0*587 + 219*114) / 1000 = 24 → dark → white
    # RGB (128, 128, 128) → luma = 128 → not > 128 → white
    # RGB (129, 129, 129) → luma = 129 → > 128 → black
    source "$DIR/tint"
    local result
    # Exactly at 128: (128*299 + 128*587 + 128*114) / 1000 = 128 → not > 128 → white
    result=$(_tint_fg_for_bg "#808080")
    [ "$result" = "#ffffff" ]
    # Just above: (129*299 + 129*587 + 129*114) / 1000 = 129 → > 128 → black
    result=$(_tint_fg_for_bg "#818181")
    [ "$result" = "#000000" ]
}

@test "_tint_fg_for_bg works with light bg" {
    source "$DIR/tint"
    local result
    # #fdf6e3 is light → should return black
    result=$(_tint_fg_for_bg "#fdf6e3")
    [ "$result" = "#000000" ]
}

@test "_tint_fg_for_bg works with solarized-dark" {
    source "$DIR/tint"
    local result
    # solarized-dark:#002b36 is dark → should return white
    result=$(_tint_fg_for_bg "#002b36")
    [ "$result" = "#ffffff" ]
}

@test "tint_reset sends OSC 111, OSC 110, and OSC 104" {
    # Verify tint_reset includes all three reset codes
    source "$DIR/tint"
    local fn_body
    fn_body=$(type tint_reset)
    [[ "$fn_body" == *"111"* ]]
    [[ "$fn_body" == *"110"* ]]
    [[ "$fn_body" == *"104"* ]]
}

@test "tint_set sends both OSC 11 and OSC 10" {
    source "$DIR/tint"
    local fn_body
    fn_body=$(type tint_set)
    [[ "$fn_body" == *"11;"* ]]
    [[ "$fn_body" == *"10;"* ]]
}

@test "tint_set uses explicit foreground when provided" {
    source "$DIR/tint"
    local fn_body
    fn_body=$(type tint_set)
    # Second arg path exists (literal $2, not variable expansion)
    # shellcheck disable=SC2016
    [[ "$fn_body" == *'$2'* ]] || [[ "$fn_body" == *'"$2"'* ]]
}

# =============================================================================
# Palette
# =============================================================================

@test "palette has expected themes" {
    # Source directly - sourcing via function scopes the variable to that function.
    # Global setup() sets TINT_PALETTE_DIR to a nonexistent dir for hermeticity.
    source "$DIR/tint"
    [[ "$TINT_PALETTE" =~ "apprentice:#262626:" ]]
    [[ "$TINT_PALETTE" =~ "ayu:#0a0e14:" ]]
    [[ "$TINT_PALETTE" =~ "campbell:#0c0c0c:" ]]
    [[ "$TINT_PALETTE" =~ "catppuccin-frappe:#303446:" ]]
    [[ "$TINT_PALETTE" =~ "catppuccin-latte:#eff1f5:" ]]
    [[ "$TINT_PALETTE" =~ "catppuccin-macchiato:#24273a:" ]]
    [[ "$TINT_PALETTE" =~ "catppuccin-mocha:#1e1e2e:" ]]
    [[ "$TINT_PALETTE" =~ "cobalt2:#132738:" ]]
    [[ "$TINT_PALETTE" =~ "dracula:#282a36:" ]]
    [[ "$TINT_PALETTE" =~ "everforest-dark:#2d353b:" ]]
    [[ "$TINT_PALETTE" =~ "everforest-light:#fdf6e3:" ]]
    [[ "$TINT_PALETTE" =~ "github:#101216:" ]]
    [[ "$TINT_PALETTE" =~ "gruvbox-dark:#282828:" ]]
    [[ "$TINT_PALETTE" =~ "gruvbox-light:#fbf1c7:" ]]
    [[ "$TINT_PALETTE" =~ "horizon:#1c1e26:" ]]
    [[ "$TINT_PALETTE" =~ "kanagawa:#1f1f28:" ]]
    [[ "$TINT_PALETTE" =~ "linux-console:#000000:" ]]
    [[ "$TINT_PALETTE" =~ "material:#1e282c:" ]]
    [[ "$TINT_PALETTE" =~ "monokai:#272822:" ]]
    [[ "$TINT_PALETTE" =~ "night-owl:#011627:" ]]
    [[ "$TINT_PALETTE" =~ "nord:#2e3440:" ]]
    [[ "$TINT_PALETTE" =~ "onedark:#1e2127:" ]]
    [[ "$TINT_PALETTE" =~ "onelight:#fafafa:" ]]
    [[ "$TINT_PALETTE" =~ "palenight:#292d3e:" ]]
    [[ "$TINT_PALETTE" =~ "putty:#000000:" ]]
    [[ "$TINT_PALETTE" =~ "rose-pine:#191724:" ]]
    [[ "$TINT_PALETTE" =~ "rose-pine-dawn:#faf4ed:" ]]
    [[ "$TINT_PALETTE" =~ "rose-pine-moon:#232136:" ]]
    [[ "$TINT_PALETTE" =~ "solarized-dark:#002b36:" ]]
    [[ "$TINT_PALETTE" =~ "solarized-light:#fdf6e3:" ]]
    [[ "$TINT_PALETTE" =~ "synthwave:#262335:" ]]
    [[ "$TINT_PALETTE" =~ "tango:#2e3436:" ]]
    [[ "$TINT_PALETTE" =~ "tokyo:#1a1b26:" ]]
    [ "$(_tint_palette_count)" -eq 177 ]
}

@test "palette rejects hyphen-prefixed names" {
    # Names starting with - would be confused with CLI flags by cut/sed/grep
    local full="$ANSI16"
    _load_tint_with_themes custom.theme "$(printf '%s\n%s' "-badname:#abcdef${full}" "good:#123456${full}")"
    [[ "$TINT_PALETTE" =~ "good:#123456" ]]
    [[ ! "$TINT_PALETTE" =~ "-badname:" ]]
}

@test "TINT_PALETTE_DIR extends the default palette" {
    _load_tint_with_themes custom.theme 'custom:#abcdef:#112233:#000000:#111111:#222222:#333333:#444444:#555555:#666666:#777777:#888888:#999999:#aaaaaa:#bbbbbb:#cccccc:#dddddd:#eeeeee:#ffffff'
    # Built-ins preserved and user theme appended
    [[ "$TINT_PALETTE" =~ "dracula:" ]]
    [[ "$TINT_PALETTE" =~ "custom:#abcdef:" ]]
}

@test "missing TINT_PALETTE_DIR yields only built-ins" {
    TINT_PALETTE_DIR=/nonexistent-tint-test-dir source "$DIR/tint"
    [[ "$TINT_PALETTE" =~ "dracula:" ]]
    [ "$(_tint_palette_count)" -gt 0 ]
}

@test "TINT_PALETTE_DIR reads multiple files in alphabetical order" {
    local full="$ANSI16"
    _load_tint_with_themes \
        a.theme "zulu:#abcdef${full}" \
        b.theme "alpha:#123456${full}"
    [[ "$TINT_PALETTE" =~ "zulu:#abcdef:" ]]
    [[ "$TINT_PALETTE" =~ "alpha:#123456:" ]]
    # zulu (from a.theme) must come before alpha (from b.theme)
    local zulu_pos alpha_pos
    zulu_pos=$(echo "$TINT_PALETTE" | grep -n '^zulu:' | cut -d: -f1)
    alpha_pos=$(echo "$TINT_PALETTE" | grep -n '^alpha:' | cut -d: -f1)
    [ "$zulu_pos" -lt "$alpha_pos" ]
}

@test "TINT_PALETTE_DIR preserves boundaries when a file lacks trailing newline" {
    # A missing trailing newline in a.theme must not merge its last entry
    # with b.theme's first (awk record boundaries enforce this).
    local full="$ANSI16"
    local tmpdir
    tmpdir=$(mktemp -d)
    printf '%s' "first:#abcdef${full}" > "$tmpdir/a.theme"
    printf '%s\n' "second:#123456${full}" > "$tmpdir/b.theme"
    TINT_PALETTE_DIR="$tmpdir" source "$DIR/tint"
    rm -rf "$tmpdir"
    [[ "$TINT_PALETTE" =~ "first:#abcdef:" ]]
    [[ "$TINT_PALETTE" =~ "second:#123456:" ]]
}

@test "TINT_PALETTE_DIR handles filenames with spaces" {
    # Unquoted path expansion would split a "my theme.theme" filename into
    # two bogus arguments and silently drop the file.
    local full="$ANSI16"
    _load_tint_with_themes "my theme.theme" "spaced:#abcdef${full}"
    [[ "$TINT_PALETTE" =~ "spaced:#abcdef:" ]]
}

@test "TINT_PALETTE_DIR includes dotfile theme files" {
    # A bare shell glob ("$dir"/*) would skip leading-dot files. README
    # says any filename works, so .hidden.theme must be loaded.
    local full="$ANSI16"
    _load_tint_with_themes .hidden.theme "hidden:#abcdef${full}"
    [[ "$TINT_PALETTE" =~ "hidden:#abcdef:" ]]
}

@test "empty TINT_PALETTE_DIR does not error" {
    # Empty dir must not error (ls -A sidesteps zsh NOMATCH / bash failglob).
    local tmpdir
    tmpdir=$(mktemp -d)
    TINT_PALETTE_DIR="$tmpdir" source "$DIR/tint"
    rmdir "$tmpdir"
    [[ "$TINT_PALETTE" =~ "dracula:" ]]
}

@test "sourcing tint survives set -u with HOME unset" {
    # Sourcing must not abort with "HOME: unbound variable" under set -u.
    run bash -c "set -u; unset HOME XDG_CONFIG_HOME TINT_PALETTE_DIR; source '$DIR/tint'"
    [ "$status" -eq 0 ]
}

@test "unset HOME and XDG_CONFIG_HOME does not probe /.config" {
    # Missing HOME/XDG_CONFIG_HOME must not collapse to /.config/tint/themes
    # (a real path on some systems). No theme dir — built-ins only.
    run bash -c "unset HOME XDG_CONFIG_HOME TINT_PALETTE_DIR; source '$DIR/tint'; echo \"\$TINT_PALETTE\" | grep -q '^dracula:'"
    [ "$status" -eq 0 ]
}

@test "TINT_PALETTE_DIR handles filenames with shell metacharacters" {
    # POSIX heredoc expansion is one-pass: the loader's `<<EOF ... $(ls) EOF`
    # reads ls output verbatim, so a filename like 'foo$(date).theme' is not
    # re-interpreted by the shell. Lock that in with executable filenames.
    local full="$ANSI16"
    local tmpdir
    tmpdir=$(mktemp -d)
    printf '%s\n' "injectok:#abcdef${full}" > "$tmpdir/tricky\$(date).theme"
    printf '%s\n' "backtickok:#abcdef${full}" > "$tmpdir/b\`id\`.theme"
    printf '%s\n' "dollarok:#abcdef${full}" > "$tmpdir/name\$VAR.theme"
    TINT_PALETTE_DIR="$tmpdir" source "$DIR/tint"
    rm -rf "$tmpdir"
    [[ "$TINT_PALETTE" =~ "injectok:#abcdef:" ]]
    [[ "$TINT_PALETTE" =~ "backtickok:#abcdef:" ]]
    [[ "$TINT_PALETTE" =~ "dollarok:#abcdef:" ]]
}

@test "sourcing tint preserves caller's positional parameters" {
    # The loader uses `set --` inside _tint_load_palette to accumulate
    # theme file paths. Function-scoped positional params must not leak
    # to the shell that sourced tint. Verified across bash, dash, zsh.
    for sh in bash dash /usr/bin/zsh; do
        command -v "$sh" >/dev/null 2>&1 || continue
        run "$sh" -c "set -- outer1 outer2 outer3; . '$DIR/tint'; printf '%d|%s|%s|%s' \"\$#\" \"\$1\" \"\$2\" \"\$3\""
        [ "$status" -eq 0 ]
        [ "$output" = "3|outer1|outer2|outer3" ]
    done
}

@test "TINT_PALETTE_DIR follows symlinked directory" {
    # Loader must follow a symlinked theme dir (common dotfile pattern).
    local full="$ANSI16"
    local realdir linkdir
    realdir=$(mktemp -d)
    linkdir=$(mktemp -d)/themes
    echo "viasymlink:#abcdef${full}" > "$realdir/file.theme"
    ln -s "$realdir" "$linkdir"
    TINT_PALETTE_DIR="$linkdir" source "$DIR/tint"
    rm -rf "$realdir" "$(dirname "$linkdir")"
    [[ "$TINT_PALETTE" =~ "viasymlink:#abcdef:" ]]
}

@test "empty TINT_PALETTE_DIR disables user themes" {
    # Explicit TINT_PALETTE_DIR= must short-circuit the XDG/HOME chain so
    # callers can run hermetically without inventing a fake directory.
    run bash -c "TINT_PALETTE_DIR= source '$DIR/tint'; echo \"\$TINT_PALETTE\" | grep -q '^dracula:'"
    [ "$status" -eq 0 ]
}

@test "relative HOME is ignored in theme-dir fallback" {
    _assert_relative_path_ignored HOME relhome relhome/.config/tint/themes
}

@test "relative XDG_CONFIG_HOME is ignored" {
    _assert_relative_path_ignored XDG_CONFIG_HOME .config .config/tint/themes
}

@test "user theme name colliding with built-in is dropped" {
    # Dedup keeps the first match; built-ins come first, so a user file
    # naming itself "dracula" never ends up in TINT_PALETTE. Keeps the
    # picker and tint_lookup consistent (no "pick this, can't recall it").
    local full="$ANSI16"
    _load_tint_with_themes mine.theme "dracula:#deadbe${full}"
    # Only one dracula in palette and it's the built-in (#282a36).
    [ "$(echo "$TINT_PALETTE" | grep -c '^dracula:')" -eq 1 ]
    [[ "$TINT_PALETTE" =~ "dracula:#282a36:" ]]
    [[ ! "$TINT_PALETTE" =~ "dracula:#deadbe:" ]]
}

@test "user theme reusing a built-in bg+fg pair is kept" {
    # An ANSI-only variant of dracula (same #282a36/#f8f8f2 pair, different
    # name, different ANSI slots) stays reachable by name. The picker's
    # current-theme auto-detect degrades gracefully to first-match on that
    # bg+fg ambiguity, but users can still select the theme directly.
    local rest=':#000000:#111111:#222222:#333333:#444444:#555555:#666666:#777777:#888888:#999999:#aaaaaa:#bbbbbb:#cccccc:#dddddd:#eeeeee:#ffffff'
    _load_tint_with_themes ansionly.theme "ansionly:#282a36:#f8f8f2${rest}"
    [[ "$TINT_PALETTE" =~ "dracula:#282a36:#f8f8f2" ]]
    [[ "$TINT_PALETTE" =~ "ansionly:#282a36:#f8f8f2" ]]
}

@test "relative TINT_PALETTE_DIR is ignored" {
    _assert_relative_path_ignored TINT_PALETTE_DIR themes themes
}

@test "tint_reload_palette picks up TINT_PALETTE_DIR changed after sourcing" {
    # Library mode: source once, then change TINT_PALETTE_DIR, then reload.
    local full="$ANSI16"
    local tmpdir
    tmpdir=$(mktemp -d)
    echo "lateload:#abcdef${full}" > "$tmpdir/x.theme"
    source "$DIR/tint"
    [[ ! "$TINT_PALETTE" =~ "lateload:" ]]
    TINT_PALETTE_DIR="$tmpdir" tint_reload_palette
    rm -rf "$tmpdir"
    [[ "$TINT_PALETTE" =~ "lateload:#abcdef:" ]]
}

@test "absolute TINT_PALETTE_DIR with dash component loads cleanly" {
    # A leading "/" in $TINT_PALETTE_DIR prevents a dash-prefixed component
    # (e.g. /tmp/foo/-themes) from being read as an option.
    local full="$ANSI16"
    local parent
    parent=$(mktemp -d)
    mkdir "$parent/-themes"
    echo "dashy:#abcdef${full}" > "$parent/-themes/x.theme"
    TINT_PALETTE_DIR="$parent/-themes" source "$DIR/tint"
    rm -rf "$parent"
    [[ "$TINT_PALETTE" =~ "dashy:#abcdef:" ]]
}

@test "TINT_PALETTE_DIR loads symlinked theme files" {
    # Loader must follow symlinks to regular theme files
    # (common dotfile pattern: *.theme symlinked into the theme dir).
    local full="$ANSI16"
    local realdir linkdir
    realdir=$(mktemp -d)
    linkdir=$(mktemp -d)
    echo "linkfile:#abcdef${full}" > "$realdir/orig.theme"
    ln -s "$realdir/orig.theme" "$linkdir/link.theme"
    TINT_PALETTE_DIR="$linkdir" source "$DIR/tint"
    rm -rf "$realdir" "$linkdir"
    [[ "$TINT_PALETTE" =~ "linkfile:#abcdef:" ]]
}

@test "empty palette does not crash _tint_load_palette_arrays" {
    # When TINT_PALETTE has no valid name:#hex entries, _tint_load_palette_arrays
    # must skip malformed lines instead of crashing on arithmetic expansion.
    run bash -c "source '$DIR/tint'; TINT_PALETTE=''; _tint_load_palette_arrays"
    [ "$status" -eq 0 ]
}

@test "malformed hex does not crash _tint_load_palette_arrays" {
    # Truncated hex like 'bad:#12' bypasses the empty check but crashes
    # on 16#${hex:5:2} with empty substring. Guard must validate full #RRGGBB.
    run bash -c "source '$DIR/tint'; TINT_PALETTE='bad:#12'; _tint_load_palette_arrays"
    [ "$status" -eq 0 ]
}

@test "palette validates full 18-color theme entries" {
    # Only entries with all 18 hex values (bg + fg + 16 ANSI) pass validation
    _load_tint_with_themes test.theme 'test:#aabbcc:#112233:#000000:#111111:#222222:#333333:#444444:#555555:#666666:#777777:#888888:#999999:#aaaaaa:#bbbbbb:#cccccc:#dddddd:#eeeeee:#ffffff'
    [[ "$TINT_PALETTE" =~ "test:#aabbcc:" ]]
}

@test "palette rejects legacy bg-only entries" {
    # Old name:#bg format is no longer valid
    _load_tint_with_themes legacy.theme 'old:#abcdef'
    [[ ! "$TINT_PALETTE" =~ "old:#abcdef" ]]
}

@test "tint_lookup returns full theme string" {
    source "$DIR/tint"
    local result
    result=$(tint_lookup "dracula")
    # Should contain bg, fg, and 16 ANSI colors (18 colon-separated hex values)
    local field_count
    field_count=$(echo "$result" | tr ':' '\n' | wc -l)
    [ "$field_count" -eq 18 ]
    # First field is bg
    [[ "$result" == "#282a36:"* ]]
    # Second field is fg
    [[ "$result" == "#282a36:#f8f8f2:"* ]]
}

@test "tint --list shows only names" {
    run tint --list
    [ "$status" -eq 0 ]
    # Each line should be a bare theme name with no hex values
    local line
    while IFS= read -r line; do
        [[ "$line" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]]
        [[ ! "$line" =~ '#' ]]
    done <<<"$output"
}

# =============================================================================
# Code Invariants
# =============================================================================

@test "_tint_query_osc_color is defined as subshell function" {
    # _tint_query_osc_color must use ( ) not { } so trap/stty changes are isolated.
    grep -qE '_tint_query_osc_color\(\)[[:space:]]*\(' "$DIR/tint" || {
        echo "_tint_query_osc_color is not a subshell function"
        return 1
    }
}

@test "_tint_query_osc_color has no bash-specific trap branching" {
    # With subshell isolation, there should be no BASH_VERSION checks or
    # trap -p / eval saved trap logic in the query functions.
    # Note: can't use `! grep` in bats — set -e is suppressed by `!`,
    # so failures would be silently ignored.
    local query_section
    query_section=$(grep -A30 '_tint_query_osc_color' "$DIR/tint")
    if echo "$query_section" | grep -q 'BASH_VERSION'; then
        echo "Found BASH_VERSION in _tint_query_osc_color"; return 1
    fi
    if echo "$query_section" | grep -q 'trap -p'; then
        echo "Found trap -p in _tint_query_osc_color"; return 1
    fi
    if echo "$query_section" | grep -q '_tq_saved_trap'; then
        echo "Found _tq_saved_trap in _tint_query_osc_color"; return 1
    fi
}

# =============================================================================
# Picker: Model
# =============================================================================

@test "model: down from 0" {
    source "$DIR/tint"
    _TINT_PICKER_IDX=0
    _TINT_PICKER_OLD_IDX=0
    local _tint_last_idx=9
    _tint_model_move_cursor down
    [ "$_TINT_PICKER_IDX" -eq 1 ]
    [ "$_TINT_PICKER_OLD_IDX" -eq 0 ]
}

@test "model: up from 0 wraps to last" {
    source "$DIR/tint"
    _TINT_PICKER_IDX=0
    _TINT_PICKER_OLD_IDX=0
    local _tint_last_idx=9
    _tint_model_move_cursor up
    [ "$_TINT_PICKER_IDX" -eq 9 ]
    [ "$_TINT_PICKER_OLD_IDX" -eq 0 ]
}

@test "model: down from last wraps to 0" {
    source "$DIR/tint"
    _TINT_PICKER_IDX=9
    _TINT_PICKER_OLD_IDX=0
    local _tint_last_idx=9
    _tint_model_move_cursor down
    [ "$_TINT_PICKER_IDX" -eq 0 ]
    [ "$_TINT_PICKER_OLD_IDX" -eq 9 ]
}

@test "model: up from middle" {
    source "$DIR/tint"
    _TINT_PICKER_IDX=5
    _TINT_PICKER_OLD_IDX=0
    local _tint_last_idx=9
    _tint_model_move_cursor up
    [ "$_TINT_PICKER_IDX" -eq 4 ]
    [ "$_TINT_PICKER_OLD_IDX" -eq 5 ]
}

@test "model: consecutive moves track OLD_IDX" {
    source "$DIR/tint"
    _TINT_PICKER_IDX=0
    _TINT_PICKER_OLD_IDX=0
    local _tint_last_idx=9
    _tint_model_move_cursor down
    _tint_model_move_cursor down
    _tint_model_move_cursor down
    [ "$_TINT_PICKER_IDX" -eq 3 ]
    [ "$_TINT_PICKER_OLD_IDX" -eq 2 ]
}

@test "scroll: all fit on screen" {
    source "$DIR/tint"
    _TINT_PICKER_IDX=0
    _TINT_PICKER_TOTAL=5
    _TINT_PICKER_VISIBLE=10
    _TINT_PICKER_WIN_START=0
    _TINT_PICKER_WIN_END=0
    _TINT_PICKER_RENDERED_ROWS=0
    _tint_update_scroll_window
    [ "$_TINT_PICKER_WIN_START" -eq 0 ]
    [ "$_TINT_PICKER_WIN_END" -eq 4 ]
    [ "$_TINT_PICKER_SCROLLED" -eq 0 ]
}

@test "scroll: initial window centers cursor" {
    source "$DIR/tint"
    _TINT_PICKER_IDX=15
    _TINT_PICKER_TOTAL=30
    _TINT_PICKER_VISIBLE=10
    _TINT_PICKER_WIN_START=0
    _TINT_PICKER_WIN_END=0
    _TINT_PICKER_RENDERED_ROWS=0
    _tint_update_scroll_window
    [ "$_TINT_PICKER_WIN_START" -eq 10 ]
    [ "$_TINT_PICKER_WIN_END" -eq 19 ]
    [ "$_TINT_PICKER_SCROLLED" -eq 1 ]
}

@test "scroll: initial window clamps to start" {
    source "$DIR/tint"
    _TINT_PICKER_IDX=2
    _TINT_PICKER_TOTAL=30
    _TINT_PICKER_VISIBLE=10
    _TINT_PICKER_WIN_START=0
    _TINT_PICKER_WIN_END=0
    _TINT_PICKER_RENDERED_ROWS=0
    _tint_update_scroll_window
    [ "$_TINT_PICKER_WIN_START" -eq 0 ]
    [ "$_TINT_PICKER_WIN_END" -eq 9 ]
    [ "$_TINT_PICKER_SCROLLED" -eq 0 ]
}

@test "scroll: initial window clamps to end" {
    source "$DIR/tint"
    _TINT_PICKER_IDX=28
    _TINT_PICKER_TOTAL=30
    _TINT_PICKER_VISIBLE=10
    _TINT_PICKER_WIN_START=0
    _TINT_PICKER_WIN_END=0
    _TINT_PICKER_RENDERED_ROWS=0
    _tint_update_scroll_window
    [ "$_TINT_PICKER_WIN_START" -eq 20 ]
    [ "$_TINT_PICKER_WIN_END" -eq 29 ]
    [ "$_TINT_PICKER_SCROLLED" -eq 1 ]
}

@test "scroll: cursor below window shifts down" {
    source "$DIR/tint"
    _TINT_PICKER_IDX=15
    _TINT_PICKER_TOTAL=30
    _TINT_PICKER_VISIBLE=10
    _TINT_PICKER_WIN_START=0
    _TINT_PICKER_WIN_END=9
    _TINT_PICKER_RENDERED_ROWS=5
    _tint_update_scroll_window
    [ "$_TINT_PICKER_WIN_END" -eq 15 ]
    [ "$_TINT_PICKER_WIN_START" -eq 6 ]
    [ "$_TINT_PICKER_SCROLLED" -eq 1 ]
}

@test "scroll: cursor above window shifts up" {
    source "$DIR/tint"
    _TINT_PICKER_IDX=3
    _TINT_PICKER_TOTAL=30
    _TINT_PICKER_VISIBLE=10
    _TINT_PICKER_WIN_START=10
    _TINT_PICKER_WIN_END=19
    _TINT_PICKER_RENDERED_ROWS=5
    _tint_update_scroll_window
    [ "$_TINT_PICKER_WIN_START" -eq 3 ]
    [ "$_TINT_PICKER_WIN_END" -eq 12 ]
    [ "$_TINT_PICKER_SCROLLED" -eq 1 ]
}

@test "scroll: cursor within window no scroll" {
    source "$DIR/tint"
    _TINT_PICKER_IDX=5
    _TINT_PICKER_TOTAL=30
    _TINT_PICKER_VISIBLE=10
    _TINT_PICKER_WIN_START=0
    _TINT_PICKER_WIN_END=9
    _TINT_PICKER_RENDERED_ROWS=5
    _tint_update_scroll_window
    [ "$_TINT_PICKER_WIN_START" -eq 0 ]
    [ "$_TINT_PICKER_WIN_END" -eq 9 ]
    [ "$_TINT_PICKER_SCROLLED" -eq 0 ]
}

@test "scroll: scrolled flag resets after no-scroll update" {
    source "$DIR/tint"
    _TINT_PICKER_IDX=15
    _TINT_PICKER_TOTAL=30
    _TINT_PICKER_VISIBLE=10
    _TINT_PICKER_WIN_START=0
    _TINT_PICKER_WIN_END=9
    _TINT_PICKER_RENDERED_ROWS=5
    _tint_update_scroll_window
    [ "$_TINT_PICKER_SCROLLED" -eq 1 ]
    # Now move within the window — scrolled should reset
    _TINT_PICKER_IDX=10
    _tint_update_scroll_window
    [ "$_TINT_PICKER_SCROLLED" -eq 0 ]
}

# Helper: set up state for _tint_handle_resize tests.
# Stubs terminal I/O functions (erase, render, height) so the model logic
# can be tested without a PTY.
_setup_resize() {
    source "$DIR/tint"
    # Stub I/O: erase, render, hint, height query, preview
    # shellcheck disable=SC2317
    _tint_erase_picker() { :; }
    # shellcheck disable=SC2317
    _tint_render_hint_line() { :; }
    # shellcheck disable=SC2317
    _tint_render_all() { :; }
    # shellcheck disable=SC2317
    _tint_apply_preview_color() { :; }
    _tint_resize_height=24
    # shellcheck disable=SC2317
    _tint_get_terminal_height() { echo "$_tint_resize_height"; }
    # Palette arrays (need real entries for render/scroll to reference)
    _tint_themes_name=(unchanged a b c d e f g h i j k l m n o p q r s)
    _tint_themes_bg=(unused x x x x x x x x x x x x x x x x x x x)
    _TINT_PICKER_TOTAL=20
    _TINT_PICKER_RESIZED=0
}

@test "resize: recalculates visible rows for larger terminal" {
    _setup_resize
    # Initial state: 10-row terminal, cursor at 5, window 0-7
    _TINT_PICKER_VISIBLE=8
    _TINT_PICKER_IDX=5
    _TINT_PICKER_WIN_START=0
    _TINT_PICKER_WIN_END=7
    _TINT_PICKER_RENDERED_ROWS=8
    # Grow terminal to 20 rows → visible = 20 - 2 = 18
    _tint_resize_height=20
    _tint_handle_resize
    [ "$_TINT_PICKER_VISIBLE" -eq 18 ]
    [ "$_TINT_PICKER_RESIZED" -eq 0 ]
    # Cursor should still be visible in the new window
    [ "$_TINT_PICKER_IDX" -eq 5 ]
    [ "$_TINT_PICKER_WIN_START" -le 5 ]
    [ "$_TINT_PICKER_WIN_END" -ge 5 ]
}

@test "resize: recalculates visible rows for smaller terminal" {
    _setup_resize
    # Initial state: 20-row terminal, cursor at 15, window 2-19
    _TINT_PICKER_VISIBLE=18
    _TINT_PICKER_IDX=15
    _TINT_PICKER_WIN_START=2
    _TINT_PICKER_WIN_END=19
    _TINT_PICKER_RENDERED_ROWS=18
    # Shrink terminal to 8 rows → visible = 8 - 2 = 6
    _tint_resize_height=8
    _tint_handle_resize
    [ "$_TINT_PICKER_VISIBLE" -eq 6 ]
    # Cursor at 15 should still be visible
    [ "$_TINT_PICKER_WIN_START" -le 15 ]
    [ "$_TINT_PICKER_WIN_END" -ge 15 ]
}

@test "resize: clamps visible to total when terminal is huge" {
    _setup_resize
    _TINT_PICKER_VISIBLE=10
    _TINT_PICKER_IDX=5
    _TINT_PICKER_WIN_START=0
    _TINT_PICKER_WIN_END=9
    _TINT_PICKER_RENDERED_ROWS=10
    # Terminal has 100 rows → visible would be 98, but total is only 20
    _tint_resize_height=100
    _tint_handle_resize
    [ "$_TINT_PICKER_VISIBLE" -eq 20 ]
    [ "$_TINT_PICKER_WIN_START" -eq 0 ]
    [ "$_TINT_PICKER_WIN_END" -eq 19 ]
}

@test "resize: clamps visible to 1 for tiny terminal" {
    _setup_resize
    _TINT_PICKER_VISIBLE=10
    _TINT_PICKER_IDX=5
    _TINT_PICKER_WIN_START=0
    _TINT_PICKER_WIN_END=9
    _TINT_PICKER_RENDERED_ROWS=10
    # Terminal has 2 rows → visible = 2 - 2 = 0, clamped to 1
    _tint_resize_height=2
    _tint_handle_resize
    [ "$_TINT_PICKER_VISIBLE" -eq 1 ]
}

# Helper: set up minimal state for _tint_render_row tests
_setup_render_row() {
    source "$DIR/tint"
    _tint_themes_name=(unused "solarized-dark")
    _tint_themes_bg=(unused "#002b36")
    _tint_themes_bg_r=(0 0) _tint_themes_bg_g=(0 43) _tint_themes_bg_b=(0 54)
    _tint_themes_fg_r=(0 131) _tint_themes_fg_g=(0 148) _tint_themes_fg_b=(0 150)
    _TINT_PICKER_TOTAL=2
    _TINT_PICKER_DEFAULT=0
    _TINT_PICKER_ORIGINAL_BG="#f0e1d2"
    _TINT_PICKER_ROW_WIDTH=40
    _tint_picker_buf=""
}

# =============================================================================
# Picker: View
# =============================================================================

@test "render: highlighted row has cursor marker" {
    _setup_render_row
    _tint_render_row 1 1
    [[ "$_tint_picker_buf" == *"> "* ]]
}

@test "render: unhighlighted row has no marker" {
    _setup_render_row
    _tint_render_row 1 0
    [[ "$_tint_picker_buf" != *"> "* ]]
    [[ "$_tint_picker_buf" != *"* "* ]]
}

@test "render: default row has star marker" {
    _setup_render_row
    _TINT_PICKER_DEFAULT=1
    _tint_render_row 1 0
    [[ "$_tint_picker_buf" == *"* "* ]]
}

@test "render: row 0 with original bg shows unchanged" {
    _setup_render_row
    _tint_render_row 0 0
    [[ "$_tint_picker_buf" == *"(unchanged)"* ]]
}

@test "render: row 0 without original bg shows reset to default" {
    _setup_render_row
    _TINT_PICKER_ORIGINAL_BG=""
    _tint_render_row 0 0
    [[ "$_tint_picker_buf" == *"(reset to default)"* ]]
}

@test "render: row includes theme name" {
    _setup_render_row
    _tint_render_row 1 0
    [[ "$_tint_picker_buf" == *"solarized-dark"* ]]
}


@test "render: highlighted row has true-color fg and bg" {
    _setup_render_row
    _tint_render_row 1 1
    [[ "$_tint_picker_buf" == *"38;2;"* ]]
    [[ "$_tint_picker_buf" == *"48;2;"* ]]
    [[ "$_tint_picker_buf" != *$'\e[2;'* ]]
}

@test "render: unhighlighted row is not dimmed" {
    # Unhighlighted rows must not apply SGR 2 dim; the fg preview must
    # show each theme's actual color. Highlight is marker-only.
    _setup_render_row
    _tint_render_row 1 0
    [[ "$_tint_picker_buf" == *"38;2;"* ]]
    [[ "$_tint_picker_buf" != *$'\e[2;'* ]]
}

@test "render: row 0 default also gets star" {
    _setup_render_row
    _TINT_PICKER_DEFAULT=1
    _tint_render_row 0 0
    [[ "$_tint_picker_buf" == *"* "* ]]
}

@test "scroll indicator: both arrows when scrolled mid" {
    source "$DIR/tint"
    _TINT_PICKER_WIN_START=5
    _TINT_PICKER_WIN_END=14
    _TINT_PICKER_TOTAL=30
    _tint_picker_buf=""
    _tint_render_scroll_indicator
    [[ "$_tint_picker_buf" == *"↑ 5 more"* ]]
    [[ "$_tint_picker_buf" == *"↓ 15 more"* ]]
}

@test "scroll indicator: up arrow only at bottom" {
    source "$DIR/tint"
    _TINT_PICKER_WIN_START=20
    _TINT_PICKER_WIN_END=29
    _TINT_PICKER_TOTAL=30
    _tint_picker_buf=""
    _tint_render_scroll_indicator
    [[ "$_tint_picker_buf" == *"↑ 20 more"* ]]
    [[ "$_tint_picker_buf" != *"↓"* ]]
}

@test "scroll indicator: down arrow only at top" {
    source "$DIR/tint"
    _TINT_PICKER_WIN_START=0
    _TINT_PICKER_WIN_END=9
    _TINT_PICKER_TOTAL=30
    _tint_picker_buf=""
    _tint_render_scroll_indicator
    [[ "$_tint_picker_buf" == *"↓ 20 more"* ]]
    [[ "$_tint_picker_buf" != *"↑"* ]]
}

@test "scroll indicator: no indicator when all visible" {
    source "$DIR/tint"
    _TINT_PICKER_WIN_START=0
    _TINT_PICKER_WIN_END=4
    _TINT_PICKER_TOTAL=5
    _tint_picker_buf=""
    _tint_render_scroll_indicator
    [[ "$_tint_picker_buf" != *"↑"* ]]
    [[ "$_tint_picker_buf" != *"↓"* ]]
}

# =============================================================================
# Picker: OSC 11 Guard
# =============================================================================

# Helper: run tint_pick in a PTY with _tint_query_terminal_bg stubbed to fail.
# Accepts optional env var exports to simulate tmux/SSH contexts.
# Usage: _pick_unsupported [env_setup_cmd]
# Sets: UNSUPPORTED_OUTPUT (captured stderr+stdout)
_pick_unsupported() {
    local env_setup="${1:-}"
    UNSUPPORTED_OUTPUT=$(python3 - "$DIR" "$env_setup" <<'PYEOF'
import os, sys, time, select
tint_dir, env_setup = sys.argv[1], sys.argv[2]
master, slave = os.openpty()
pid = os.fork()
if pid == 0:
    os.setsid(); os.close(master)
    sp = os.ttyname(slave); c = os.open(sp, os.O_RDWR); os.close(c)
    os.dup2(slave, 0); os.dup2(slave, 1); os.dup2(slave, 2)
    if slave > 2: os.close(slave)
    cmd_prefix = (env_setup + '; ') if env_setup else ''
    cmd = cmd_prefix + "source '" + tint_dir + "/tint'; _tint_query_terminal_bg() { return 1; }; tint_pick 2>&1; echo EXIT:$?"
    os.execvp('bash', ['bash', '-c', cmd])
else:
    os.close(slave)
    out = b''
    child_exited = False
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        if not child_exited:
            try:
                wpid, _ = os.waitpid(pid, os.WNOHANG)
                if wpid == pid: child_exited = True
            except ChildProcessError: child_exited = True
        r, _, _ = select.select([master], [], [], 0.1)
        if r:
            try:
                c = os.read(master, 4096)
                if not c: break
                out += c
            except OSError: break
        elif child_exited:
            break
    print(out.decode('utf-8', 'replace'))
PYEOF
)
}

@test "tint_pick fails with diagnostic when OSC 11 unsupported" {
    _pick_unsupported
    [[ "$UNSUPPORTED_OUTPUT" =~ "OSC 11" ]]
    [[ "$UNSUPPORTED_OUTPUT" =~ "did not respond" ]]
    [[ "$UNSUPPORTED_OUTPUT" =~ "EXIT:1" ]]
}

@test "_pick_unsupported env_setup without trailing semicolon" {
    # env_setup without a trailing '; ' must not break the shell command string
    _pick_unsupported "export TINT_TEST_MARKER=1"
    [[ "$UNSUPPORTED_OUTPUT" =~ "EXIT:1" ]]
}

@test "tint_pick OSC 11 error shows tmux hint when TMUX is set" {
    _pick_unsupported "export TMUX=/tmp/tmux-1000/default,1,0"
    [[ "$UNSUPPORTED_OUTPUT" =~ "tmux set -g allow-passthrough on" ]]
    [[ ! "$UNSUPPORTED_OUTPUT" =~ "ssh -t" ]]
}

@test "tint_pick OSC 11 error shows SSH hint when SSH_CONNECTION is set" {
    _pick_unsupported "export SSH_CONNECTION='1.2.3.4 1234 5.6.7.8 22'"
    [[ "$UNSUPPORTED_OUTPUT" =~ "ssh -t" ]]
    [[ ! "$UNSUPPORTED_OUTPUT" =~ "tmux" ]]
}

@test "tint_pick OSC 11 error shows SSH hint when SSH_TTY is set" {
    _pick_unsupported "export SSH_TTY=/dev/pts/0"
    [[ "$UNSUPPORTED_OUTPUT" =~ "ssh -t" ]]
}

@test "tint_pick OSC 11 error prefers tmux hint over SSH" {
    _pick_unsupported "export TMUX=/tmp/tmux-1000/default,1,0; export SSH_CONNECTION='1.2.3.4 1234 5.6.7.8 22'"
    [[ "$UNSUPPORTED_OUTPUT" =~ "tmux set -g allow-passthrough on" ]]
    [[ ! "$UNSUPPORTED_OUTPUT" =~ "ssh -t" ]]
}

@test "tint_pick OSC 11 error shows no hint in plain terminal" {
    _pick_unsupported "unset TMUX SSH_TTY SSH_CONNECTION"
    [[ ! "$UNSUPPORTED_OUTPUT" =~ "Hint:" ]]
    [[ "$UNSUPPORTED_OUTPUT" =~ "OSC 11" ]]
    [[ "$UNSUPPORTED_OUTPUT" =~ "Try: printf" ]]
    [[ "$UNSUPPORTED_OUTPUT" == *"033]11;?"* ]]
}

# =============================================================================
# Picker: Theme Auto-Detect (ORIGINAL_THEME_IDX)
# =============================================================================

# Helper: set up minimal state for auto-detect tests.
# Accepts TINT_PALETTE content, stub bg, and optional stub fg.
# Stubs terminal functions so _tint_init_picker can run without a PTY.
# Usage: _setup_autodetect <palette> <orig_bg> [orig_fg]
# After call: check _TINT_PICKER_ORIGINAL_THEME_IDX and _TINT_PICKER_DEFAULT
_setup_autodetect() {
    source "$DIR/tint"
    TINT_PALETTE="$1"
    local stub_bg="$2" stub_fg="${3:-}"
    _tint_query_terminal_bg() { printf '%s' "$stub_bg"; }
    if [ -n "$stub_fg" ]; then
        _tint_query_terminal_fg() { printf '%s' "$stub_fg"; }
    else
        _tint_query_terminal_fg() { return 1; }
    fi
    _tint_get_terminal_height() { echo 24; }
    _tint_install_signal_traps() { :; }
    _tint_setup_terminal() { :; }
    _tint_init_picker
}

@test "auto-detect: unique bg match sets ORIGINAL_THEME_IDX" {
    _setup_autodetect \
        $'alpha:#002b36:#839496\nbeta:#1a1b26:#c0caf5' \
        '#002b36' '#839496'
    [ "$_TINT_PICKER_ORIGINAL_THEME_IDX" -eq 1 ]
}

@test "auto-detect: no bg match sets ORIGINAL_THEME_IDX to 0" {
    _setup_autodetect \
        $'alpha:#002b36:#839496\nbeta:#1a1b26:#c0caf5' \
        '#ffffff' '#000000'
    [ "$_TINT_PICKER_ORIGINAL_THEME_IDX" -eq 0 ]
}

@test "auto-detect: multiple bg matches disambiguated by fg" {
    _setup_autodetect \
        $'alpha:#002b36:#839496\nbeta:#002b36:#c0caf5\ngamma:#1a1b26:#c0caf5' \
        '#002b36' '#c0caf5'
    [ "$_TINT_PICKER_ORIGINAL_THEME_IDX" -eq 2 ]
}

@test "auto-detect: multiple bg matches, fg matches first candidate" {
    _setup_autodetect \
        $'alpha:#002b36:#839496\nbeta:#002b36:#c0caf5\ngamma:#1a1b26:#c0caf5' \
        '#002b36' '#839496'
    [ "$_TINT_PICKER_ORIGINAL_THEME_IDX" -eq 1 ]
}

@test "auto-detect: multiple bg matches, no fg available falls back to 0" {
    _setup_autodetect \
        $'alpha:#002b36:#839496\nbeta:#002b36:#c0caf5' \
        '#002b36'
    [ "$_TINT_PICKER_ORIGINAL_THEME_IDX" -eq 0 ]
}

@test "auto-detect: multiple bg matches, fg matches none falls back to 0" {
    _setup_autodetect \
        $'alpha:#002b36:#839496\nbeta:#002b36:#c0caf5' \
        '#002b36' '#ffffff'
    [ "$_TINT_PICKER_ORIGINAL_THEME_IDX" -eq 0 ]
}

@test "auto-detect: multiple bg+fg matches (still ambiguous) falls back to 0" {
    _setup_autodetect \
        $'alpha:#002b36:#839496\nbeta:#002b36:#839496\ngamma:#1a1b26:#c0caf5' \
        '#002b36' '#839496'
    [ "$_TINT_PICKER_ORIGINAL_THEME_IDX" -eq 0 ]
}

@test "auto-detect: case-insensitive bg matching" {
    _setup_autodetect \
        $'alpha:#002B36:#839496' \
        '#002b36' '#839496'
    [ "$_TINT_PICKER_ORIGINAL_THEME_IDX" -eq 1 ]
}

@test "auto-detect: case-insensitive fg tiebreaker" {
    _setup_autodetect \
        $'alpha:#002b36:#839496\nbeta:#002b36:#C0CAF5' \
        '#002b36' '#c0caf5'
    [ "$_TINT_PICKER_ORIGINAL_THEME_IDX" -eq 2 ]
}

@test "auto-detect: star marker falls back to auto-detect when no explicit arg" {
    _setup_autodetect \
        $'alpha:#002b36:#839496\nbeta:#1a1b26:#c0caf5' \
        '#002b36' '#839496'
    # No explicit arg → _TINT_PICKER_DEFAULT should adopt ORIGINAL_THEME_IDX
    [ "$_TINT_PICKER_DEFAULT" -eq "$_TINT_PICKER_ORIGINAL_THEME_IDX" ]
    [ "$_TINT_PICKER_DEFAULT" -eq 1 ]
}

@test "auto-detect: star marker keeps explicit arg over auto-detect" {
    source "$DIR/tint"
    TINT_PALETTE=$'alpha:#002b36:#839496\nbeta:#1a1b26:#c0caf5'
    # shellcheck disable=SC2317
    _tint_query_terminal_bg() { printf '%s' '#002b36'; }
    # shellcheck disable=SC2317
    _tint_query_terminal_fg() { printf '%s' '#839496'; }
    # shellcheck disable=SC2317
    _tint_get_terminal_height() { echo 24; }
    # shellcheck disable=SC2317
    _tint_install_signal_traps() { :; }
    # shellcheck disable=SC2317
    _tint_setup_terminal() { :; }
    # Pass explicit theme name → DEFAULT should point there, not auto-detect
    _tint_init_picker "beta"
    [ "$_TINT_PICKER_DEFAULT" -eq 2 ]
    [ "$_TINT_PICKER_ORIGINAL_THEME_IDX" -eq 1 ]
}

@test "auto-detect: full theme string disambiguates by fg" {
    _setup_autodetect \
        $'alpha:#002b36:#839496\nbeta:#002b36:#c0caf5' \
        '#002b36' '#c0caf5'
    # Pass beta's full theme string — should select beta (idx 2), not alpha
    _tint_find_default_index '#002b36:#c0caf5'
    [ "$_TINT_PICKER_DEFAULT" -eq 2 ]
}

@test "auto-detect: empty ORIGINAL_BG leaves ORIGINAL_THEME_IDX at 0" {
    source "$DIR/tint"
    TINT_PALETTE=$'alpha:#002b36:#839496'
    # shellcheck disable=SC2317
    _tint_query_terminal_bg() { printf '%s' ''; }
    # shellcheck disable=SC2317
    _tint_query_terminal_fg() { printf '%s' '#839496'; }
    # shellcheck disable=SC2317
    _tint_get_terminal_height() { echo 24; }
    # shellcheck disable=SC2317
    _tint_install_signal_traps() { :; }
    # shellcheck disable=SC2317
    _tint_setup_terminal() { :; }
    _tint_init_picker
    [ "$_TINT_PICKER_ORIGINAL_THEME_IDX" -eq 0 ]
}

@test "auto-detect: unique bg match without fg trusts bg" {
    _setup_autodetect \
        $'alpha:#002b36:#839496\nbeta:#1a1b26:#c0caf5' \
        '#002b36'
    [ "$_TINT_PICKER_ORIGINAL_THEME_IDX" -eq 1 ]
}

@test "auto-detect: single bg match with mismatched fg rejects theme" {
    _setup_autodetect \
        $'alpha:#002b36:#839496\nbeta:#1a1b26:#c0caf5' \
        '#002b36' '#ffffff'
    [ "$_TINT_PICKER_ORIGINAL_THEME_IDX" -eq 0 ]
}

@test "auto-detect: full 18-field theme strings with fg disambiguation" {
    _setup_autodetect \
        $'alpha:#002b36:#839496:#073642:#dc322f:#859900:#b58900:#268bd2:#d33682:#2aa198:#eee8d5:#002b36:#cb4b16:#586e75:#657b83:#839496:#6c71c4:#93a1a1:#fdf6e3\nbeta:#002b36:#c0caf5:#073642:#dc322f:#859900:#b58900:#268bd2:#d33682:#2aa198:#eee8d5:#002b36:#cb4b16:#586e75:#657b83:#839496:#6c71c4:#93a1a1:#fdf6e3' \
        '#002b36' '#c0caf5'
    [ "$_TINT_PICKER_ORIGINAL_THEME_IDX" -eq 2 ]
}

@test "restore: theme match + queried fg → tint_set theme fg" {
    run bash -c '
        source "$1"
        TINT_PALETTE="alpha:#002b36:#839496"
        _tint_load_palette_arrays
        _TINT_PICKER_PREVIEWED=1
        _TINT_PICKER_ORIGINAL_THEME_IDX=1
        _TINT_PICKER_ORIGINAL_BG="#002b36"
        _TINT_PICKER_ORIGINAL_FG="#ffffff"
        tint_set() { printf "tint_set"; for a; do printf "|%s" "$a"; done; echo; }
        tint_reset() { echo "tint_reset"; }
        _tint_restore_original_colors
    ' -- "$DIR/tint"
    [ "$status" -eq 0 ]
    [ "$output" = "tint_set|#002b36:#839496|#ffffff" ]
}

@test "restore: theme match, no fg → tint_set theme only" {
    run bash -c '
        source "$1"
        TINT_PALETTE="alpha:#002b36:#839496"
        _tint_load_palette_arrays
        _TINT_PICKER_PREVIEWED=1
        _TINT_PICKER_ORIGINAL_THEME_IDX=1
        _TINT_PICKER_ORIGINAL_BG="#002b36"
        _TINT_PICKER_ORIGINAL_FG=""
        tint_set() { printf "tint_set"; for a; do printf "|%s" "$a"; done; echo; }
        tint_reset() { echo "tint_reset"; }
        _tint_restore_original_colors
    ' -- "$DIR/tint"
    [ "$status" -eq 0 ]
    [ "$output" = "tint_set|#002b36:#839496" ]
}

@test "restore: no theme match, bg+fg queried → tint_set bg fg" {
    run bash -c '
        source "$1"
        TINT_PALETTE="alpha:#002b36:#839496"
        _tint_load_palette_arrays
        _TINT_PICKER_PREVIEWED=1
        _TINT_PICKER_ORIGINAL_THEME_IDX=0
        _TINT_PICKER_ORIGINAL_BG="#aabbcc"
        _TINT_PICKER_ORIGINAL_FG="#ffffff"
        tint_set() { printf "tint_set"; for a; do printf "|%s" "$a"; done; echo; }
        tint_reset() { echo "tint_reset"; }
        _tint_restore_original_colors
    ' -- "$DIR/tint"
    [ "$status" -eq 0 ]
    [ "$output" = "tint_set|#aabbcc|#ffffff" ]
}

@test "restore: no theme match, bg only → tint_set bg empty-fg" {
    run bash -c '
        source "$1"
        TINT_PALETTE="alpha:#002b36:#839496"
        _tint_load_palette_arrays
        _TINT_PICKER_PREVIEWED=1
        _TINT_PICKER_ORIGINAL_THEME_IDX=0
        _TINT_PICKER_ORIGINAL_BG="#aabbcc"
        _TINT_PICKER_ORIGINAL_FG=""
        tint_set() { printf "tint_set"; for a; do printf "|%s" "$a"; done; echo; }
        tint_reset() { echo "tint_reset"; }
        _tint_restore_original_colors
    ' -- "$DIR/tint"
    [ "$status" -eq 0 ]
    [ "$output" = "tint_set|#aabbcc|" ]
}

@test "restore: nothing queried → tint_reset" {
    run bash -c '
        source "$1"
        TINT_PALETTE="alpha:#002b36:#839496"
        _tint_load_palette_arrays
        _TINT_PICKER_PREVIEWED=1
        _TINT_PICKER_ORIGINAL_THEME_IDX=0
        _TINT_PICKER_ORIGINAL_BG=""
        _TINT_PICKER_ORIGINAL_FG=""
        tint_set() { printf "tint_set"; for a; do printf "|%s" "$a"; done; echo; }
        tint_reset() { echo "tint_reset"; }
        _tint_restore_original_colors
    ' -- "$DIR/tint"
    [ "$status" -eq 0 ]
    [ "$output" = "tint_reset" ]
}

@test "restore: no preview applied → no-op" {
    run bash -c '
        source "$1"
        TINT_PALETTE="alpha:#002b36:#839496"
        _tint_load_palette_arrays
        _TINT_PICKER_PREVIEWED=0
        _TINT_PICKER_ORIGINAL_THEME_IDX=1
        _TINT_PICKER_ORIGINAL_BG="#002b36"
        _TINT_PICKER_ORIGINAL_FG="#839496"
        tint_set() { printf "tint_set"; for a; do printf "|%s" "$a"; done; echo; }
        tint_reset() { echo "tint_reset"; }
        _tint_restore_original_colors
    ' -- "$DIR/tint"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

# =============================================================================
# Picker: Navigation
# =============================================================================

# Helper: generate N copies of a key name for _pick arguments
# Usage: _repeat_keys <key> <count>
# Stdout: space-separated key names (use with: _pick $(_repeat_keys down 5) enter)
_repeat_keys() {
    local key="$1" n="$2" i result=""
    for ((i = 0; i < n; i++)); do
        result+="$key "
    done
    printf '%s' "$result"
}

# Helper: run tint_pick in a PTY with simulated keystrokes
# Usage: _pick <key> [<key> ...]
# Sets: PICK_EXIT, PICK_STDOUT, PICK_STTY_ECHO, PICK_ALT_SCREEN_EXITED
_pick() {
    local result
    result=$(python3 "$DIR/test/pty_helper.py" "$@" 2>/dev/null)
    PICK_EXIT=$(echo "$result" | grep '^exit:' | cut -d: -f2)
    PICK_STDOUT=$(echo "$result" | grep '^stdout:' | cut -d: -f2-)
    PICK_STTY_ECHO=$(echo "$result" | grep '^stty_echo:' | cut -d: -f2)
    PICK_ALT_SCREEN_EXITED=$(echo "$result" | grep '^alt_screen_exited:' | cut -d: -f2)
}

@test "picker: navigate down and select" {
    _pick down enter
    [ "$PICK_EXIT" -eq 0 ]
    [ "$PICK_STDOUT" = "$THEME_FIRST" ]
}

@test "picker: up wraps to last entry" {
    _pick up enter
    [ "$PICK_EXIT" -eq 0 ]
    [ "$PICK_STDOUT" = "$THEME_LAST" ]
}

@test "picker: down then up returns to start" {
    _pick down up enter
    [ "$PICK_EXIT" -eq 0 ]
    [ "$PICK_STDOUT" = "" ]  # idx 0 = unchanged (no theme name)
}

@test "picker: multiple navigations" {
    _pick down down down enter
    [ "$PICK_EXIT" -eq 0 ]
    [ "$PICK_STDOUT" = "$THEME_THIRD" ]
}

@test "picker: j/k vim keys work" {
    _pick j j enter
    [ "$PICK_EXIT" -eq 0 ]
    [ "$PICK_STDOUT" = "$THEME_SECOND" ]
}

@test "picker: j/k vim keys with wrapping" {
    # ITEM_COUNT j's from idx 0 wraps back to idx 0, one more to idx 1.
    # Then k back to idx 0.
    # shellcheck disable=SC2046
    _pick $(_repeat_keys j $((ITEM_COUNT + 1))) k enter
    [ "$PICK_EXIT" -eq 0 ]
    [ "$PICK_STDOUT" = "" ]  # idx 0 = unchanged (no theme name)
}

@test "picker: right/left arrows work as alternate bindings" {
    # Right/left are mapped to down/up for convenience.
    _pick right right enter
    [ "$PICK_EXIT" -eq 0 ]
    [ "$PICK_STDOUT" = "$THEME_SECOND" ]
}

@test "picker: h/l vim keys work as alternate bindings" {
    # h/l are mapped to up/down for convenience.
    _pick l l enter
    [ "$PICK_EXIT" -eq 0 ]
    [ "$PICK_STDOUT" = "$THEME_SECOND" ]
}

@test "picker: navigate to last theme" {
    # PALETTE_COUNT downs from idx 0 → last palette entry.
    # shellcheck disable=SC2046
    _pick $(_repeat_keys down "$PALETTE_COUNT") enter
    [ "$PICK_EXIT" -eq 0 ]
    [ "$PICK_STDOUT" = "$THEME_LAST" ]
}

@test "picker: navigate down then back up" {
    # Down 4 then up 2 → idx 2 (second theme).
    _pick down down down down up up enter
    [ "$PICK_EXIT" -eq 0 ]
    [ "$PICK_STDOUT" = "$THEME_SECOND" ]
}

@test "picker: down past last entry wraps to start" {
    # ITEM_COUNT downs from idx 0 wraps back to idx 0.
    # shellcheck disable=SC2046
    _pick $(_repeat_keys down "$ITEM_COUNT") enter
    [ "$PICK_EXIT" -eq 0 ]
    [ "$PICK_STDOUT" = "" ]  # idx 0 = unchanged (no theme name)
}

@test "picker: wrap to end then continue up" {
    # Up from idx 0 wraps to last, then 2 more ups → third from last.
    _pick up up up enter
    [ "$PICK_EXIT" -eq 0 ]
    [ "$PICK_STDOUT" = "$THEME_THIRD_LAST" ]
}

@test "picker: cancel with escape" {
    _pick down escape
    [ "$PICK_EXIT" -eq 1 ]
    [ "$PICK_STDOUT" = "" ]
}

@test "picker: cancel with q" {
    _pick down q
    [ "$PICK_EXIT" -eq 1 ]
    [ "$PICK_STDOUT" = "" ]
}

@test "picker: teardown resets rendered rows for idempotent erase" {
    # Signal trap and picker loop both call _tint_restore_terminal. If
    # _TINT_PICKER_RENDERED_ROWS isn't reset after erase, a second call
    # moves the cursor up again and clears lines above the picker.
    run bash -c "
        source '$DIR/tint'
        _TINT_PICKER_RENDERED_ROWS=5
        _TINT_PICKER_CURSOR_HIDDEN=0
        _TINT_PICKER_EXIT_REASON=cancel
        _TINT_PICKER_TRAPS_INSTALLED=0
        _TINT_PICKER_SAVED_STTY=''
        _tint_restore_terminal
        echo \$_TINT_PICKER_RENDERED_ROWS
    "
    [ "$status" -eq 0 ]
    [ "${lines[$((${#lines[@]}-1))]}" = "0" ]
}

@test "picker: many keypresses do not hang under PTY backpressure" {
    # Full-frame redraw per keypress can fill the PTY buffer when
    # the master side isn't draining continuously, blocking the child's
    # write and preventing it from reading further keys — deadlock.
    # Multiple wrapping navigations exercise enough redraws to test backpressure.
    command -v timeout >/dev/null || skip "timeout(1) not installed (brew install coreutils on macOS)"
    run timeout 5 python3 "$DIR/test/pty_helper.py" \
        down down down down down down down down down down \
        down down down down down enter
    [ "$status" -eq 0 ]
    [[ "$output" == *"exit:0"* ]]
}

@test "picker: SIGWINCH triggers redraw and picker remains functional" {
    # Resize the PTY mid-session (10 rows → triggers recalculation of
    # _TINT_PICKER_VISIBLE), then navigate and select to verify the picker
    # survived the signal and redrew correctly.
    command -v timeout >/dev/null || skip "timeout(1) not installed (brew install coreutils on macOS)"
    run timeout 10 python3 "$DIR/test/pty_helper.py" \
        down resize:10x80 down enter
    [ "$status" -eq 0 ]
    [[ "$output" == *"exit:0"* ]]
    # down + down = idx 2 (second theme)
    [[ "$output" == *"stdout:${THEME_SECOND}"* ]]
}

# Termination signals (INT/TERM) must run the full teardown chain — the
# class-level invariant being: whenever the picker is interrupted, the user
# must get back a normal shell. Specifically:
#   - tint_pick returns the canonical signal exit code (130 / 143)
#   - stty -echo is cleared (terminal echo restored)
#   - the alt-screen buffer is exited (\e[?1049l emitted)
# These tests catch any future change that breaks any of those steps —
# e.g. a regression in the trap install dedupe (#97) or in
# _tint_restore_terminal's ordering would surface here.

@test "picker: SIGINT triggers full teardown and exits 130" {
    command -v timeout >/dev/null || skip "timeout(1) not installed (brew install coreutils on macOS)"
    run timeout 10 python3 "$DIR/test/pty_helper.py" down signal:int
    [ "$status" -eq 0 ]
    [[ "$output" == *"exit:130"* ]]
    [[ "$output" == *"stty_echo:on"* ]]
    [[ "$output" == *"alt_screen_exited:yes"* ]]
}

@test "picker: SIGTERM triggers full teardown and exits 143" {
    command -v timeout >/dev/null || skip "timeout(1) not installed (brew install coreutils on macOS)"
    run timeout 10 python3 "$DIR/test/pty_helper.py" down signal:term
    [ "$status" -eq 0 ]
    [[ "$output" == *"exit:143"* ]]
    [[ "$output" == *"stty_echo:on"* ]]
    [[ "$output" == *"alt_screen_exited:yes"* ]]
}

# =============================================================================
# Picker: Shell Guards
# =============================================================================

@test "tint_pick rejects headless invocation" {
    # tint_pick checks /dev/tty accessibility (not -t 0/-t 1, since stdout
    # is piped in hex=$(tint_pick) usage). Should fail early with a clear
    # message in headless contexts where /dev/tty is unavailable.
    # Note: < /dev/null only redirects stdin; /dev/tty is still accessible
    # from an interactive terminal. Use setsid to detach from the controlling
    # terminal so /dev/tty becomes unavailable.
    command -v setsid >/dev/null || skip "setsid(1) not installed (brew install util-linux on macOS)"
    run setsid bash -c "source '$DIR/tint' && tint_pick"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "requires a terminal" ]]
}

@test "tint_pick rejects non-bash shell with leaked BASH_VERSION" {
    # BASH_VERSION can leak via environment into non-bash shells (e.g., dash).
    # tint_pick must use a subshell array syntax test, not simple presence checks.
    run env BASH_VERSION=5 dash -c ". '$DIR/tint'; tint_pick"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "requires bash" ]]
    # Without the guard, dash would hit ${BASH_SOURCE[0]} and crash with
    # "Bad substitution" instead of the clean "requires bash" error.
    [[ ! "$output" =~ "Bad substitution" ]]
}

@test "tint_pick rejects non-bash shell with spoofed BASH_VERSINFO" {
    # BASH_VERSINFO can be set as a plain env var, fooling presence checks.
    # Only real bash can parse array subscript syntax like ${BASH_VERSINFO[0]}.
    run env BASH_VERSINFO=5 dash -c ". '$DIR/tint'; tint_pick"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "requires bash" ]]
    [[ ! "$output" =~ "Bad substitution" ]]  # same guard as above
}

# =============================================================================
# Picker: EXIT Trap
# =============================================================================

@test "tint_pick preserves caller EXIT trap in direct call" {
    # tint_pick must restore the caller's EXIT trap when called directly
    # (not in command substitution).
    local result
    result=$(python3 - "$DIR" <<'PYEOF'
import os, sys, time, select
tint_dir = sys.argv[1]
master, slave = os.openpty()
pid = os.fork()
if pid == 0:
    os.setsid(); os.close(master)
    sp = os.ttyname(slave); c = os.open(sp, os.O_RDWR); os.close(c)
    os.dup2(slave, 0); os.dup2(slave, 1); os.dup2(slave, 2)
    if slave > 2: os.close(slave)
    cmd = "source '" + tint_dir + "/tint'; _tint_query_terminal_bg() { printf '%s' '#f0e1d2'; }; _tint_query_terminal_fg() { printf '%s' '#1a1b26'; }; trap 'echo MYTRAP' EXIT; tint_pick >/dev/null; trap -p EXIT"
    os.execvp('bash', ['bash', '-c', cmd])
else:
    os.close(slave)
    time.sleep(0.1)
    os.write(master, b'q')
    out = b''
    while True:
        r, _, _ = select.select([master], [], [], 0.05)
        if r:
            try:
                c = os.read(master, 4096)
                if not c: break
                out += c
            except OSError: break
        p2, status = os.waitpid(pid, os.WNOHANG)
        if p2 != 0:
            # Child exited — drain remaining buffered output, then stop.
            while True:
                r, _, _ = select.select([master], [], [], 0.02)
                if not r: break
                try:
                    c = os.read(master, 4096)
                    if not c: break
                    out += c
                except OSError: break
            break
    print(out.decode('utf-8', 'replace'))
PYEOF
)
    # The caller's EXIT trap should still be present after tint_pick returns
    [[ "$result" =~ "echo MYTRAP" ]]
}

@test "tint_pick in subshell does not corrupt stdout with EXIT trap" {
    # result=$(tint_pick) must not include caller EXIT trap output.
    local result
    result=$(python3 - "$DIR" <<'PYEOF'
import os, sys, time, select
tint_dir = sys.argv[1]
master, slave = os.openpty()
pid = os.fork()
if pid == 0:
    os.setsid(); os.close(master)
    sp = os.ttyname(slave); c = os.open(sp, os.O_RDWR); os.close(c)
    os.dup2(slave, 0); os.dup2(slave, 1); os.dup2(slave, 2)
    if slave > 2: os.close(slave)
    cmd = "source '" + tint_dir + "/tint'; _tint_query_terminal_bg() { printf '%s' '#f0e1d2'; }; _tint_query_terminal_fg() { printf '%s' '#1a1b26'; }; trap 'echo LEAKED' EXIT; result=$(tint_pick); echo RESULT:$result"
    os.execvp('bash', ['bash', '-c', cmd])
else:
    os.close(slave)
    time.sleep(0.1)
    os.write(master, b'\x1b[C')
    time.sleep(0.02)
    os.write(master, b'\r')
    out = b''
    while True:
        r, _, _ = select.select([master], [], [], 0.05)
        if r:
            try:
                c = os.read(master, 4096)
                if not c: break
                out += c
            except OSError: break
        p2, status = os.waitpid(pid, os.WNOHANG)
        if p2 != 0:
            # Child exited — drain remaining buffered output, then stop.
            while True:
                r, _, _ = select.select([master], [], [], 0.02)
                if not r: break
                try:
                    c = os.read(master, 4096)
                    if not c: break
                    out += c
                except OSError: break
            break
    print(out.decode('utf-8', 'replace'))
PYEOF
)
    # RESULT value should be a clean theme name, not contaminated with trap output.
    # "LEAKED" will appear later (from the parent's EXIT trap), which is fine —
    # it just must not be part of the result= capture.
    # Strip control characters (PTY adds \r, escape sequences) before matching.
    local clean
    clean=$(printf '%s' "$result" | sed $'s/\x1b\\][^\x1b\x07]*\\(\x1b\\\\\\|\x07\\)//g; s/\x1b\\[[0-9;]*[A-Za-z]//g; s/\r//g')
    [[ "$clean" =~ RESULT:${THEME_FIRST} ]]
    # Verify "LEAKED" is not embedded in the result capture
    [[ ! "$clean" =~ RESULT:${THEME_FIRST}LEAKED ]]
}

@test "tint_pick subshell stdout clean when BASHPID unset (Bash 3.2 compat)" {
    # BASHPID doesn't exist on Bash 3.2, so ${BASHPID:-$$} always equals $$
    # even inside command substitution. Without a working subshell check,
    # result=$(tint_pick) would save/restore the EXIT trap inside the subshell,
    # leaking trap output into the captured value. BASH_SUBSHELL (Bash 3.0+)
    # correctly distinguishes subshells from direct calls.
    local result
    result=$(python3 - "$DIR" <<'PYEOF'
import os, sys, time, select
tint_dir = sys.argv[1]
master, slave = os.openpty()
pid = os.fork()
if pid == 0:
    os.setsid(); os.close(master)
    sp = os.ttyname(slave); c = os.open(sp, os.O_RDWR); os.close(c)
    os.dup2(slave, 0); os.dup2(slave, 1); os.dup2(slave, 2)
    if slave > 2: os.close(slave)
    cmd = "source '" + tint_dir + "/tint'; _tint_query_terminal_bg() { printf '%s' '#f0e1d2'; }; _tint_query_terminal_fg() { printf '%s' '#1a1b26'; }; unset BASHPID; trap 'echo LEAKED' EXIT; result=$(tint_pick); echo RESULT:$result"
    os.execvp('bash', ['bash', '-c', cmd])
else:
    os.close(slave)
    time.sleep(0.1)
    os.write(master, b'\x1b[C')
    time.sleep(0.02)
    os.write(master, b'\r')
    out = b''
    while True:
        r, _, _ = select.select([master], [], [], 0.05)
        if r:
            try:
                c = os.read(master, 4096)
                if not c: break
                out += c
            except OSError: break
        p2, status = os.waitpid(pid, os.WNOHANG)
        if p2 != 0:
            # Child exited — drain remaining buffered output, then stop.
            while True:
                r, _, _ = select.select([master], [], [], 0.02)
                if not r: break
                try:
                    c = os.read(master, 4096)
                    if not c: break
                    out += c
                except OSError: break
            break
    print(out.decode('utf-8', 'replace'))
PYEOF
)
    local clean
    clean=$(printf '%s' "$result" | sed $'s/\x1b\\][^\x1b\x07]*\\(\x1b\\\\\\|\x07\\)//g; s/\x1b\\[[0-9;]*[A-Za-z]//g; s/\r//g')
    [[ "$clean" =~ RESULT:${THEME_FIRST} ]]
    # LEAKED must not be embedded in the result capture
    [[ ! "$clean" =~ RESULT:${THEME_FIRST}LEAKED ]]
}

# =============================================================================
# Picker: Terminal State Cleanup
# =============================================================================

@test "picker: stty echo restored after enter" {
    _pick down enter
    [ "$PICK_EXIT" -eq 0 ]
    [ "$PICK_STTY_ECHO" = "on" ]
}

@test "picker: stty echo restored after escape" {
    _pick down escape
    [ "$PICK_EXIT" -eq 1 ]
    [ "$PICK_STTY_ECHO" = "on" ]
}

@test "picker: stty echo restored after q" {
    _pick down q
    [ "$PICK_EXIT" -eq 1 ]
    [ "$PICK_STTY_ECHO" = "on" ]
}

@test "picker: stty echo restored after selecting unchanged" {
    _pick enter
    [ "$PICK_EXIT" -eq 0 ]
    [ "$PICK_STTY_ECHO" = "on" ]
}

# =============================================================================
# Picker: Misc
# =============================================================================

@test "picker tests work from non-repo directory" {
    # pty_helper.py resolves the tint script path via $DIR, not cwd.
    # Verify tests pass even when invoked from a different directory.
    cd /tmp
    run bats "$DIR/test/tint.bats" -f "picker: navigate down and select"
    [ "$status" -eq 0 ]
}

# =============================================================================
# Hook
# =============================================================================

@test "tint hook bash outputs shell code" {
    run tint hook bash
    [ "$status" -eq 0 ]
    [[ "$output" =~ _tint_hook ]]
    [[ "$output" =~ "PROMPT_COMMAND" ]]
}

@test "tint hook zsh outputs shell code" {
    run tint hook zsh
    [ "$status" -eq 0 ]
    [[ "$output" =~ _tint_hook ]]
    [[ "$output" =~ "chpwd_functions" ]]
}

@test "tint hook with no shell arg fails" {
    run tint hook
    [ "$status" -eq 1 ]
    [[ "$output" =~ "usage" ]]
}

@test "tint hook fish fails with unsupported shell" {
    run tint hook fish
    [ "$status" -eq 1 ]
    [[ "$output" =~ "unsupported shell" ]]
}

@test "bash hook is valid bash" {
    run bash -c "eval \"\$(tint hook bash)\"; type _tint_hook"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "function" ]]
}

@test "bash hook preserves exit status" {
    run bash -c "
        eval \"\$(tint hook bash)\"
        false
        _tint_hook
        echo \$?
    "
    [ "$status" -eq 0 ]
    [[ "${lines[$((${#lines[@]}-1))]}" = "1" ]]
}

@test "PROMPT_COMMAND is idempotent" {
    run bash -c "
        eval \"\$(tint hook bash)\"
        eval \"\$(tint hook bash)\"
        echo \"\$PROMPT_COMMAND\"
    "
    [ "$status" -eq 0 ]
    local count
    count=$(echo "${lines[$((${#lines[@]}-1))]}" | grep -o '_tint_hook' | wc -l)
    [ "$count" -eq 1 ]
}

@test "hook reads .tint file" {
    local tmpdir
    tmpdir=$(mktemp -d)
    echo "solarized-dark" > "$tmpdir/.tint"
    mkdir -p "$tmpdir/bin"
    cat > "$tmpdir/bin/tint" <<'STUB'
#!/bin/sh
echo "$*" >> "${TINT_LOG}"
STUB
    chmod +x "$tmpdir/bin/tint"
    run bash -c "
        export PATH=\"$tmpdir/bin:\$PATH\"
        export TINT_LOG='$tmpdir/log'
        eval \"\$('$DIR/tint' hook bash)\"
        _TINT_HOOK_PWD=''
        _TINT_HOOK_COLOR=''
        rm -f '$tmpdir/log'
        cd '$tmpdir'
        _tint_hook
        cat '$tmpdir/log'
    "
    rm -rf "$tmpdir"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "solarized-dark" ]]
}

@test "walk-up finds parent .tint" {
    local tmpdir
    tmpdir=$(mktemp -d)
    echo "nord" > "$tmpdir/.tint"
    mkdir -p "$tmpdir/child/grandchild"
    mkdir -p "$tmpdir/bin"
    cat > "$tmpdir/bin/tint" <<'STUB'
#!/bin/sh
echo "$*" >> "${TINT_LOG}"
STUB
    chmod +x "$tmpdir/bin/tint"
    run bash -c "
        export PATH=\"$tmpdir/bin:\$PATH\"
        export TINT_LOG='$tmpdir/log'
        eval \"\$('$DIR/tint' hook bash)\"
        _TINT_HOOK_PWD=''
        _TINT_HOOK_COLOR=''
        rm -f '$tmpdir/log'
        cd '$tmpdir/child/grandchild'
        _tint_hook
        cat '$tmpdir/log'
    "
    rm -rf "$tmpdir"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "nord" ]]
}

@test "no .tint means no tint call (sticky)" {
    local tmpdir
    tmpdir=$(mktemp -d)
    mkdir -p "$tmpdir/nocolor"
    mkdir -p "$tmpdir/bin"
    cat > "$tmpdir/bin/tint" <<'STUB'
#!/bin/sh
echo "$*" >> "${TINT_LOG}"
STUB
    chmod +x "$tmpdir/bin/tint"
    run bash -c "
        export PATH=\"$tmpdir/bin:\$PATH\"
        export TINT_LOG='$tmpdir/log'
        eval \"\$('$DIR/tint' hook bash)\"
        _TINT_HOOK_PWD=''
        _TINT_HOOK_COLOR=''
        rm -f '$tmpdir/log'
        cd '$tmpdir/nocolor'
        _tint_hook
        [ ! -f '$tmpdir/log' ] && echo 'NO_CALL'
    "
    rm -rf "$tmpdir"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "NO_CALL" ]]
}

@test "empty .tint means no tint call" {
    local tmpdir
    tmpdir=$(mktemp -d)
    touch "$tmpdir/.tint"
    mkdir -p "$tmpdir/bin"
    cat > "$tmpdir/bin/tint" <<'STUB'
#!/bin/sh
echo "$*" >> "${TINT_LOG}"
STUB
    chmod +x "$tmpdir/bin/tint"
    run bash -c "
        export PATH=\"$tmpdir/bin:\$PATH\"
        export TINT_LOG='$tmpdir/log'
        eval \"\$('$DIR/tint' hook bash)\"
        _TINT_HOOK_PWD=''
        _TINT_HOOK_COLOR=''
        rm -f '$tmpdir/log'
        cd '$tmpdir'
        _tint_hook
        [ ! -f '$tmpdir/log' ] && echo 'NO_CALL'
    "
    rm -rf "$tmpdir"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "NO_CALL" ]]
}

@test "unreadable .tint is skipped silently" {
    local tmpdir
    tmpdir=$(mktemp -d)
    echo "solarized-dark" > "$tmpdir/.tint"
    chmod 000 "$tmpdir/.tint"
    mkdir -p "$tmpdir/bin"
    cat > "$tmpdir/bin/tint" <<'STUB'
#!/bin/sh
echo "$*" >> "${TINT_LOG}"
STUB
    chmod +x "$tmpdir/bin/tint"
    run bash -c "
        export PATH=\"$tmpdir/bin:\$PATH\"
        export TINT_LOG='$tmpdir/log'
        eval \"\$('$DIR/tint' hook bash)\"
        _TINT_HOOK_PWD=''
        _TINT_HOOK_COLOR=''
        rm -f '$tmpdir/log'
        cd '$tmpdir'
        _tint_hook 2>'$tmpdir/stderr'
        if [ ! -f '$tmpdir/log' ] && [ ! -s '$tmpdir/stderr' ]; then echo 'SILENT_SKIP'; fi
    "
    chmod 644 "$tmpdir/.tint"
    rm -rf "$tmpdir"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "SILENT_SKIP" ]]
}

@test "non-regular .tint is skipped" {
    local tmpdir
    tmpdir=$(mktemp -d)
    mkfifo "$tmpdir/.tint"
    mkdir -p "$tmpdir/bin"
    cat > "$tmpdir/bin/tint" <<'STUB'
#!/bin/sh
echo "$*" >> "${TINT_LOG}"
STUB
    chmod +x "$tmpdir/bin/tint"
    run bash -c "
        export PATH=\"$tmpdir/bin:\$PATH\"
        export TINT_LOG='$tmpdir/log'
        eval \"\$('$DIR/tint' hook bash)\"
        _TINT_HOOK_PWD=''
        _TINT_HOOK_COLOR=''
        rm -f '$tmpdir/log'
        cd '$tmpdir'
        _tint_hook
        [ ! -f '$tmpdir/log' ] && echo 'NO_CALL'
    "
    rm -rf "$tmpdir"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "NO_CALL" ]]
}

@test "theme cache prevents redundant calls" {
    local tmpdir
    tmpdir=$(mktemp -d)
    echo "solarized-dark" > "$tmpdir/.tint"
    mkdir -p "$tmpdir/sub1" "$tmpdir/sub2"
    mkdir -p "$tmpdir/bin"
    cat > "$tmpdir/bin/tint" <<'STUB'
#!/bin/sh
echo "$*" >> "${TINT_LOG}"
STUB
    chmod +x "$tmpdir/bin/tint"
    run bash -c "
        export PATH=\"$tmpdir/bin:\$PATH\"
        export TINT_LOG='$tmpdir/log'
        eval \"\$('$DIR/tint' hook bash)\"
        _TINT_HOOK_PWD=''
        _TINT_HOOK_COLOR=''
        rm -f '$tmpdir/log'
        cd '$tmpdir/sub1'
        _tint_hook
        cd '$tmpdir/sub2'
        _tint_hook
        wc -l < '$tmpdir/log'
    "
    rm -rf "$tmpdir"
    [ "$status" -eq 0 ]
    [[ "${lines[$((${#lines[@]}-1))]}" =~ ^[[:space:]]*1$ ]]
}

@test ".tint with reset calls tint reset" {
    local tmpdir
    tmpdir=$(mktemp -d)
    echo "reset" > "$tmpdir/.tint"
    mkdir -p "$tmpdir/bin"
    cat > "$tmpdir/bin/tint" <<'STUB'
#!/bin/sh
echo "$*" >> "${TINT_LOG}"
STUB
    chmod +x "$tmpdir/bin/tint"
    run bash -c "
        export PATH=\"$tmpdir/bin:\$PATH\"
        export TINT_LOG='$tmpdir/log'
        eval \"\$('$DIR/tint' hook bash)\"
        _TINT_HOOK_PWD=''
        _TINT_HOOK_COLOR=''
        rm -f '$tmpdir/log'
        cd '$tmpdir'
        _tint_hook
        cat '$tmpdir/log'
    "
    rm -rf "$tmpdir"
    [ "$status" -eq 0 ]
    [[ "${lines[$((${#lines[@]}-1))]}" = "reset" ]]
}

@test "hook strips inline comments" {
    local tmpdir
    tmpdir=$(mktemp -d)
    echo "solarized-dark # my theme" > "$tmpdir/.tint"
    mkdir -p "$tmpdir/bin"
    cat > "$tmpdir/bin/tint" <<'STUB'
#!/bin/sh
echo "$*" >> "${TINT_LOG}"
STUB
    chmod +x "$tmpdir/bin/tint"
    run bash -c "
        export PATH=\"$tmpdir/bin:\$PATH\"
        export TINT_LOG='$tmpdir/log'
        eval \"\$('$DIR/tint' hook bash)\"
        _TINT_HOOK_PWD=''
        _TINT_HOOK_COLOR=''
        rm -f '$tmpdir/log'
        cd '$tmpdir'
        _tint_hook
        cat '$tmpdir/log'
    "
    rm -rf "$tmpdir"
    [ "$status" -eq 0 ]
    [[ "${lines[$((${#lines[@]}-1))]}" = "solarized-dark" ]]
}

@test "hook skips full-line comments" {
    local tmpdir
    tmpdir=$(mktemp -d)
    printf '# Project X\n# Dark theme\nsolarized-dark\n' > "$tmpdir/.tint"
    mkdir -p "$tmpdir/bin"
    cat > "$tmpdir/bin/tint" <<'STUB'
#!/bin/sh
echo "$*" >> "${TINT_LOG}"
STUB
    chmod +x "$tmpdir/bin/tint"
    run bash -c "
        export PATH=\"$tmpdir/bin:\$PATH\"
        export TINT_LOG='$tmpdir/log'
        eval \"\$('$DIR/tint' hook bash)\"
        _TINT_HOOK_PWD=''
        _TINT_HOOK_COLOR=''
        rm -f '$tmpdir/log'
        cd '$tmpdir'
        _tint_hook
        cat '$tmpdir/log'
    "
    rm -rf "$tmpdir"
    [ "$status" -eq 0 ]
    [[ "${lines[$((${#lines[@]}-1))]}" = "solarized-dark" ]]
}

@test "hook treats hex color as value not comment" {
    local tmpdir
    tmpdir=$(mktemp -d)
    echo "#002b36" > "$tmpdir/.tint"
    mkdir -p "$tmpdir/bin"
    cat > "$tmpdir/bin/tint" <<'STUB'
#!/bin/sh
echo "$*" >> "${TINT_LOG}"
STUB
    chmod +x "$tmpdir/bin/tint"
    run bash -c "
        export PATH=\"$tmpdir/bin:\$PATH\"
        export TINT_LOG='$tmpdir/log'
        eval \"\$('$DIR/tint' hook bash)\"
        _TINT_HOOK_PWD=''
        _TINT_HOOK_COLOR=''
        rm -f '$tmpdir/log'
        cd '$tmpdir'
        _tint_hook
        cat '$tmpdir/log'
    "
    rm -rf "$tmpdir"
    [ "$status" -eq 0 ]
    [[ "${lines[$((${#lines[@]}-1))]}" = "#002b36" ]]
}

@test "hook treats 3-digit hex color as value not comment" {
    local tmpdir
    tmpdir=$(mktemp -d)
    echo "#abc" > "$tmpdir/.tint"
    mkdir -p "$tmpdir/bin"
    cat > "$tmpdir/bin/tint" <<'STUB'
#!/bin/sh
echo "$*" >> "${TINT_LOG}"
STUB
    chmod +x "$tmpdir/bin/tint"
    run bash -c "
        export PATH=\"$tmpdir/bin:\$PATH\"
        export TINT_LOG='$tmpdir/log'
        eval \"\$('$DIR/tint' hook bash)\"
        _TINT_HOOK_PWD=''
        _TINT_HOOK_COLOR=''
        rm -f '$tmpdir/log'
        cd '$tmpdir'
        _tint_hook
        cat '$tmpdir/log'
    "
    rm -rf "$tmpdir"
    [ "$status" -eq 0 ]
    [[ "${lines[$((${#lines[@]}-1))]}" = "#abc" ]]
}

@test "hook ignores comment-only .tint file" {
    local tmpdir
    tmpdir=$(mktemp -d)
    printf '# TODO: pick a theme\n# maybe solarized-dark?\n' > "$tmpdir/.tint"
    mkdir -p "$tmpdir/bin"
    cat > "$tmpdir/bin/tint" <<'STUB'
#!/bin/sh
echo "$*" >> "${TINT_LOG}"
STUB
    chmod +x "$tmpdir/bin/tint"
    run bash -c "
        export PATH=\"$tmpdir/bin:\$PATH\"
        export TINT_LOG='$tmpdir/log'
        eval \"\$('$DIR/tint' hook bash)\"
        _TINT_HOOK_PWD=''
        _TINT_HOOK_COLOR=''
        rm -f '$tmpdir/log'
        cd '$tmpdir'
        _tint_hook
        [ ! -f '$tmpdir/log' ] && echo 'NO_CALL'
    "
    rm -rf "$tmpdir"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "NO_CALL" ]]
}

@test "hook handles indented hex in .tint" {
    local tmpdir
    tmpdir=$(mktemp -d)
    echo "  #002b36" > "$tmpdir/.tint"
    mkdir -p "$tmpdir/bin"
    cat > "$tmpdir/bin/tint" <<'STUB'
#!/bin/sh
echo "$*" >> "${TINT_LOG}"
STUB
    chmod +x "$tmpdir/bin/tint"
    run bash -c "
        export PATH=\"$tmpdir/bin:\$PATH\"
        export TINT_LOG='$tmpdir/log'
        eval \"\$('$DIR/tint' hook bash)\"
        _TINT_HOOK_PWD=''
        _TINT_HOOK_COLOR=''
        rm -f '$tmpdir/log'
        cd '$tmpdir'
        _tint_hook
        cat '$tmpdir/log'
    "
    rm -rf "$tmpdir"
    [ "$status" -eq 0 ]
    [[ "${lines[$((${#lines[@]}-1))]}" = "#002b36" ]]
}

@test "PROMPT_COMMAND array form preserved" {
    run bash -c "
        PROMPT_COMMAND=('existing_func')
        eval \"\$('$DIR/tint' hook bash)\" 2>&1
        declare -p PROMPT_COMMAND
    "
    [ "$status" -eq 0 ]
    [[ ! "$output" =~ "local:" ]]
    [[ "$output" =~ "existing_func" ]]
    [[ "$output" =~ "_tint_hook" ]]
}

@test "cache cleared after no-.tint dir allows reapply" {
    local tmpdir nocolor
    tmpdir=$(mktemp -d)
    nocolor=$(mktemp -d)
    echo "solarized-dark" > "$tmpdir/.tint"
    mkdir -p "$tmpdir/bin"
    cat > "$tmpdir/bin/tint" <<'STUB'
#!/bin/sh
echo "$*" >> "${TINT_LOG}"
STUB
    chmod +x "$tmpdir/bin/tint"
    # Simulate: cd to .tint dir, cd to separate no-.tint dir (clears cache),
    # cd back to .tint dir — should reapply
    run bash -c "
        export PATH=\"$tmpdir/bin:\$PATH\"
        export TINT_LOG='$tmpdir/log'
        eval \"\$('$DIR/tint' hook bash)\"
        _TINT_HOOK_PWD=''
        _TINT_HOOK_COLOR=''
        rm -f '$tmpdir/log'
        cd '$tmpdir'
        _tint_hook
        cd '$nocolor'
        _tint_hook
        cd '$tmpdir'
        _tint_hook
        wc -l < '$tmpdir/log'
    "
    rm -rf "$tmpdir" "$nocolor"
    [ "$status" -eq 0 ]
    # Should have 2 calls: initial + reapply after cache clear
    [[ "${lines[$((${#lines[@]}-1))]}" =~ ^[[:space:]]*2$ ]]
}

@test "bash hook works under set -u" {
    run bash -c "
        set -u
        eval \"\$('$DIR/tint' hook bash)\"
        type _tint_hook
    "
    [ "$status" -eq 0 ]
}

@test "hook treats ambiguous #-prefixed text as comment" {
    local tmpdir
    tmpdir=$(mktemp -d)
    printf '#dark theme\nsolarized-dark\n' > "$tmpdir/.tint"
    mkdir -p "$tmpdir/bin"
    cat > "$tmpdir/bin/tint" <<'STUB'
#!/bin/sh
echo "$*" >> "${TINT_LOG}"
STUB
    chmod +x "$tmpdir/bin/tint"
    run bash -c "
        export PATH=\"$tmpdir/bin:\$PATH\"
        export TINT_LOG='$tmpdir/log'
        eval \"\$('$DIR/tint' hook bash)\"
        _TINT_HOOK_PWD=''
        _TINT_HOOK_COLOR=''
        rm -f '$tmpdir/log'
        cd '$tmpdir'
        _tint_hook
        cat '$tmpdir/log'
    "
    rm -rf "$tmpdir"
    [ "$status" -eq 0 ]
    [[ "${lines[$((${#lines[@]}-1))]}" = "solarized-dark" ]]
}

@test "hook survives set -e with empty .tint" {
    local tmpdir
    tmpdir=$(mktemp -d)
    touch "$tmpdir/.tint"
    run bash -c "
        set -e
        eval \"\$('$DIR/tint' hook bash)\"
        _TINT_HOOK_PWD=''
        cd '$tmpdir'
        _tint_hook
        echo 'SURVIVED'
    "
    rm -rf "$tmpdir"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "SURVIVED" ]]
}

@test "hook survives set -e with invalid .tint color" {
    local tmpdir
    tmpdir=$(mktemp -d)
    echo "notacolor" > "$tmpdir/.tint"
    run bash -c "
        set -e
        eval \"\$('$DIR/tint' hook bash)\"
        _TINT_HOOK_PWD=''
        cd '$tmpdir'
        _tint_hook
        echo 'SURVIVED'
    "
    rm -rf "$tmpdir"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "SURVIVED" ]]
}

@test "hook ignores option-like .tint values" {
    local tmpdir
    tmpdir=$(mktemp -d)
    echo "--list" > "$tmpdir/.tint"
    mkdir -p "$tmpdir/bin"
    cat > "$tmpdir/bin/tint" <<'STUB'
#!/bin/sh
echo "$*" >> "${TINT_LOG}"
STUB
    chmod +x "$tmpdir/bin/tint"
    run bash -c "
        export PATH=\"$tmpdir/bin:\$PATH\"
        export TINT_LOG='$tmpdir/log'
        eval \"\$('$DIR/tint' hook bash)\"
        _TINT_HOOK_PWD=''
        _TINT_HOOK_COLOR=''
        rm -f '$tmpdir/log'
        cd '$tmpdir'
        _tint_hook
        if [ -f '$tmpdir/log' ]; then echo 'CALLED'; else echo 'NO_CALL'; fi
    "
    rm -rf "$tmpdir"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "NO_CALL" ]]
}

# =============================================================================
# Hook output policy: silent on success, errors visible, opt-in verbose
# =============================================================================
#
# Class invariant: the hook is a high-frequency event (every prompt). Silence
# on the success path keeps terminals clean (per AGENTS.md value-prop). Errors
# must propagate to stderr so failures don't go unnoticed (previously the
# hook suppressed all of tint's output, including stderr — silent failures).
# TINT_HOOK_VERBOSE=1 opts into direnv-style "applied X from Y" messages for
# debugging or curious users.

@test "hook is silent on success by default" {
    # Capture both stdout and stderr (`2>&1`) — the contract is "no output
    # on either channel by default", so asserting only stdout would let
    # accidental stderr noise slip through. Explicitly `unset
    # TINT_HOOK_VERBOSE` to defeat any env pollution from the parent shell.
    local tmpdir
    tmpdir=$(mktemp -d)
    echo "dracula" > "$tmpdir/.tint"
    run bash -c "
        unset TINT_HOOK_VERBOSE
        eval \"\$('$DIR/tint' hook bash)\" </dev/null
        _TINT_HOOK_PWD=''
        _TINT_HOOK_COLOR=''
        cd '$tmpdir'
        _tint_hook 2>&1
    " </dev/null
    rm -rf "$tmpdir"
    [ "$status" -eq 0 ]
    # No output on either channel — the visible bg change IS the signal.
    [ -z "$output" ]
}

@test "hook prints to stderr when TINT_HOOK_VERBOSE=1" {
    # Capture stderr to a file so we can assert *which channel* the message
    # went to. Stdout is captured by `run` as $output. The hook's contract
    # is "verbose message on stderr, never stdout" — merging via `2>&1`
    # would let an accidental stdout regression slip past.
    local tmpdir
    tmpdir=$(mktemp -d)
    echo "dracula" > "$tmpdir/.tint"
    run bash -c "
        eval \"\$('$DIR/tint' hook bash)\" </dev/null
        _TINT_HOOK_PWD=''
        _TINT_HOOK_COLOR=''
        export TINT_HOOK_VERBOSE=1
        cd '$tmpdir'
        _tint_hook 2>'$tmpdir/stderr'
    " </dev/null
    local stderr_content
    stderr_content=$(cat "$tmpdir/stderr")
    rm -rf "$tmpdir"
    [ "$status" -eq 0 ]
    # stdout must be empty — verbose messages belong on stderr.
    [ -z "$output" ]
    # stderr carries the verbose line.
    [[ "$stderr_content" == *"tint: dracula from "* ]]
    [[ "$stderr_content" == *"/.tint"* ]]
}

@test "hook propagates tint stderr on unknown theme name" {
    # Stub `tint` that exits non-zero with a stderr message — verifies the
    # hook no longer suppresses stderr from the inner tint invocation.
    # Capture stdout and stderr separately to assert error went to stderr,
    # not stdout (a stdout error would pollute prompts and break pipes).
    # eval's auto-run (`_tint_hook` at end of hook script) walks up from
    # $PWD looking for any .tint; under our stub-tint PATH, that incidental
    # call would also write to stderr and pollute the assertion. Silence
    # eval's stderr — it's setup noise, not the SUT.
    local tmpdir
    tmpdir=$(mktemp -d)
    echo "ghost-theme" > "$tmpdir/.tint"
    mkdir -p "$tmpdir/bin"
    cat > "$tmpdir/bin/tint" <<'STUB'
#!/bin/sh
echo "tint: unknown theme: $*" >&2
exit 1
STUB
    chmod +x "$tmpdir/bin/tint"
    run bash -c "
        export PATH=\"$tmpdir/bin:\$PATH\"
        eval \"\$('$DIR/tint' hook bash)\" </dev/null 2>/dev/null
        _TINT_HOOK_PWD=''
        _TINT_HOOK_COLOR=''
        cd '$tmpdir'
        _tint_hook 2>'$tmpdir/stderr'
    " </dev/null
    local stderr_content
    stderr_content=$(cat "$tmpdir/stderr")
    rm -rf "$tmpdir"
    # Hook itself doesn't fail; nothing on stdout.
    [ -z "$output" ]
    # tint's stderr surfaced to the user.
    [[ "$stderr_content" == *"unknown theme: ghost-theme"* ]]
}

@test "hook does not abort shell under set -e when tint fails" {
    # Regression for the rewrite from `( ... ) || true` to `if ( ... )`.
    # Inner tint exits 1 (stub for unknown theme); the hook must not
    # propagate that failure to the surrounding shell. The "SURVIVED"
    # echo proves the shell stayed alive past the hook call. Capture
    # stdout (where SURVIVED goes) and stderr (where tint's error goes)
    # separately so each assertion targets the correct channel.
    local tmpdir
    tmpdir=$(mktemp -d)
    echo "ghost-theme" > "$tmpdir/.tint"
    mkdir -p "$tmpdir/bin"
    cat > "$tmpdir/bin/tint" <<'STUB'
#!/bin/sh
echo "tint: unknown theme: $*" >&2
exit 1
STUB
    chmod +x "$tmpdir/bin/tint"
    run bash -c "
        set -e
        export PATH=\"$tmpdir/bin:\$PATH\"
        eval \"\$('$DIR/tint' hook bash)\" </dev/null 2>/dev/null
        _TINT_HOOK_PWD=''
        _TINT_HOOK_COLOR=''
        cd '$tmpdir'
        _tint_hook 2>'$tmpdir/stderr'
        echo 'SURVIVED'
    " </dev/null
    local stderr_content
    stderr_content=$(cat "$tmpdir/stderr")
    rm -rf "$tmpdir"
    [ "$status" -eq 0 ]
    # stdout: surrounding shell survived past the hook.
    [[ "$output" == *"SURVIVED"* ]]
    # stderr: tint's error message surfaced.
    [[ "$stderr_content" == *"unknown theme: ghost-theme"* ]]
}

@test "extra args still rejected for other commands" {
    run tint solarized-dark extra
    [ "$status" -eq 1 ]
    [[ "$output" =~ "unexpected argument" ]]
}

@test "extra args rejected for completions subcommand" {
    run tint completions bash extra
    [ "$status" -eq 1 ]
    [[ "$output" =~ "unexpected argument" ]]
}
