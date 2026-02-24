#!/usr/bin/env bats
# shellcheck disable=SC1091,SC2030,SC2031,SC2034

setup() {
    DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    PATH="$DIR:$PATH"
    _setup_picker_constants
}

# Helper to source the library within a test (BATS runs tests in subshells)
_load_tint() {
    source "$DIR/tint"
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
    grep -q '^solarized$' <<<"$output"
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
echo "lookup=\$(tint_lookup solarized)"
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
echo "lookup=\$(tint_lookup solarized)"
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
    result=$(tint_lookup "solarized")
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

@test "tint reset resets to default" {
    # Verify the CLI prints the expected message (OSC sequences go to
    # /dev/tty and are tested separately in "type tint_reset" test)
    source "$DIR/tint"
    run bash -c "
        source '$DIR/tint'
        tint reset
    "
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Reset to terminal default" ]]
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

@test "_tint_fg_for_bg works with solarized dark" {
    source "$DIR/tint"
    local result
    # solarized:#002b36 is dark → should return white
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

@test "tint_set auto-computes foreground" {
    source "$DIR/tint"
    local fg
    # For a dark bg, fg should be white
    fg=$(_tint_fg_for_bg "#000000")
    [ "$fg" = "#ffffff" ]
    # For a light bg, fg should be black
    fg=$(_tint_fg_for_bg "#ffffff")
    [ "$fg" = "#000000" ]
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
    # Source directly - sourcing via function scopes the variable to that function
    source "$DIR/tint"
    [[ "$TINT_PALETTE" =~ "ayu:#0a0e14:" ]]
    [[ "$TINT_PALETTE" =~ "catppuccin:#1e1e2e:" ]]
    [[ "$TINT_PALETTE" =~ "cobalt:#132738:" ]]
    [[ "$TINT_PALETTE" =~ "dracula:#282a36:" ]]
    [[ "$TINT_PALETTE" =~ "everforest:#2d353b:" ]]
    [[ "$TINT_PALETTE" =~ "github:#101216:" ]]
    [[ "$TINT_PALETTE" =~ "gruvbox:#282828:" ]]
    [[ "$TINT_PALETTE" =~ "horizon:#1c1e26:" ]]
    [[ "$TINT_PALETTE" =~ "kanagawa:#1f1f28:" ]]
    [[ "$TINT_PALETTE" =~ "material:#1e282c:" ]]
    [[ "$TINT_PALETTE" =~ "monokai:#272822:" ]]
    [[ "$TINT_PALETTE" =~ "night-owl:#011627:" ]]
    [[ "$TINT_PALETTE" =~ "nord:#2e3440:" ]]
    [[ "$TINT_PALETTE" =~ "onedark:#1e2127:" ]]
    [[ "$TINT_PALETTE" =~ "palenight:#292d3e:" ]]
    [[ "$TINT_PALETTE" =~ "rose-pine:#191724:" ]]
    [[ "$TINT_PALETTE" =~ "solarized:#002b36:" ]]
    [[ "$TINT_PALETTE" =~ "synthwave:#262335:" ]]
    [[ "$TINT_PALETTE" =~ "tokyo:#1a1b26:" ]]
    [ "$(_tint_palette_count)" -eq 19 ]
}

@test "palette rejects hyphen-prefixed names" {
    # Names starting with - would be confused with CLI flags by cut/sed/grep
    local full=':#112233:#000000:#111111:#222222:#333333:#444444:#555555:#666666:#777777:#888888:#999999:#aaaaaa:#bbbbbb:#cccccc:#dddddd:#eeeeee:#ffffff'
    source "$DIR/tint"
    export TINT_PALETTE="-badname:#abcdef${full}"$'\n'"good:#123456${full}"
    source "$DIR/tint"
    # Only the valid name should survive
    [ "$(_tint_palette_count)" -eq 1 ]
    [[ "$(_tint_palette_get 1)" == "good:#123456"* ]]
}

@test "TINT_PALETTE env overrides default" {
    # Set env before sourcing so _tint_load_palette sees it as a string
    export TINT_PALETTE='custom:#abcdef:#112233:#000000:#111111:#222222:#333333:#444444:#555555:#666666:#777777:#888888:#999999:#aaaaaa:#bbbbbb:#cccccc:#dddddd:#eeeeee:#ffffff'
    source "$DIR/tint"

    [ "$(_tint_palette_count)" -eq 1 ]
    [[ "$(_tint_palette_get 1)" == "custom:#abcdef:"* ]]
}

@test "empty palette does not crash _tint_load_palette_arrays" {
    # When TINT_PALETTE has no valid name:#hex entries (e.g., 'invalid'),
    # _tint_load_palette_arrays must skip malformed lines instead of crashing on
    # arithmetic expansion with empty hex (16#${hex:1:2}).
    export TINT_PALETTE='invalid'
    source "$DIR/tint"
    run bash -c "source '$DIR/tint'; export TINT_PALETTE='invalid'; _tint_load_palette_arrays"
    [ "$status" -eq 0 ]
}

@test "malformed hex does not crash _tint_load_palette_arrays" {
    # Truncated hex like 'bad:#12' bypasses the empty check but crashes
    # on 16#${hex:5:2} with empty substring. Guard must validate full #RRGGBB.
    run bash -c "source '$DIR/tint'; export TINT_PALETTE='bad:#12'; _tint_load_palette_arrays"
    [ "$status" -eq 0 ]
}

@test "palette validates full 18-color theme entries" {
    # Only entries with all 18 hex values (bg + fg + 16 ANSI) pass validation
    source "$DIR/tint"
    local full='test:#aabbcc:#112233:#000000:#111111:#222222:#333333:#444444:#555555:#666666:#777777:#888888:#999999:#aaaaaa:#bbbbbb:#cccccc:#dddddd:#eeeeee:#ffffff'
    export TINT_PALETTE="$full"
    source "$DIR/tint"
    [ "$(_tint_palette_count)" -eq 1 ]
    [[ "$(_tint_palette_get 1)" == "test:#aabbcc:"* ]]
}

@test "palette rejects legacy bg-only entries" {
    # Old name:#bg format is no longer valid
    source "$DIR/tint"
    export TINT_PALETTE='old:#abcdef'
    source "$DIR/tint"
    [ "$(_tint_palette_count)" -eq 0 ]
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
    _tint_themes_name=(unused "solarized")
    _tint_themes_bg=(unused "#002b36")
    _tint_themes_bg_r=(0 0) _tint_themes_bg_g=(0 43) _tint_themes_bg_b=(0 54)
    _tint_picker_text_sgr=(30 97)
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
    [[ "$_tint_picker_buf" == *"solarized"* ]]
}


@test "render: highlighted row uses normal weight" {
    _setup_render_row
    _tint_render_row 1 1
    [[ "$_tint_picker_buf" == *"48;2;"* ]]
    [[ "$_tint_picker_buf" != *$'\e[2;'* ]]
}

@test "render: unhighlighted row uses dim" {
    _setup_render_row
    _tint_render_row 1 0
    [[ "$_tint_picker_buf" == *$'\e[2;'* ]]
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
# Sets: PICK_EXIT (exit code), PICK_STDOUT (captured output)
_pick() {
    local result
    result=$(python3 "$DIR/test/pty_helper.py" "$@" 2>/dev/null)
    PICK_EXIT=$(echo "$result" | grep '^exit:' | cut -d: -f2)
    PICK_STDOUT=$(echo "$result" | grep '^stdout:' | cut -d: -f2-)
    PICK_STTY_ECHO=$(echo "$result" | grep '^stty_echo:' | cut -d: -f2)
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
    [ "${lines[-1]}" = "0" ]
}

@test "picker: many keypresses do not hang under PTY backpressure" {
    # Full-frame redraw per keypress can fill the PTY buffer when
    # the master side isn't draining continuously, blocking the child's
    # write and preventing it from reading further keys — deadlock.
    # Multiple wrapping navigations exercise enough redraws to test backpressure.
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
    run timeout 10 python3 "$DIR/test/pty_helper.py" \
        down resize:10x80 down enter
    [ "$status" -eq 0 ]
    [[ "$output" == *"exit:0"* ]]
    # down + down = idx 2 (second theme)
    [[ "$output" == *"stdout:${THEME_SECOND}"* ]]
}

@test "picker: set -e does not kill script during navigation" {
    # Under set -e, [ test ] && cmd returns 1 when the test is false,
    # which kills the script. Render functions must use if/then instead.
    _pick down enter
    [ "$PICK_EXIT" -eq 0 ]
    [ "$PICK_STDOUT" = "$THEME_FIRST" ]
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
    time.sleep(0.3)
    os.write(master, b'q')
    _, status = os.waitpid(pid, 0)
    out = b''
    while True:
        r, _, _ = select.select([master], [], [], 0.1)
        if not r: break
        try:
            c = os.read(master, 4096)
            if not c: break
            out += c
        except OSError: break
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
    time.sleep(0.3)
    os.write(master, b'\x1b[C')
    time.sleep(0.05)
    os.write(master, b'\r')
    _, status = os.waitpid(pid, 0)
    out = b''
    while True:
        r, _, _ = select.select([master], [], [], 0.1)
        if not r: break
        try:
            c = os.read(master, 4096)
            if not c: break
            out += c
        except OSError: break
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
    time.sleep(0.3)
    os.write(master, b'\x1b[C')
    time.sleep(0.05)
    os.write(master, b'\r')
    _, status = os.waitpid(pid, 0)
    out = b''
    while True:
        r, _, _ = select.select([master], [], [], 0.1)
        if not r: break
        try:
            c = os.read(master, 4096)
            if not c: break
            out += c
        except OSError: break
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
    [[ "${lines[-1]}" = "1" ]]
}

@test "PROMPT_COMMAND is idempotent" {
    run bash -c "
        eval \"\$(tint hook bash)\"
        eval \"\$(tint hook bash)\"
        echo \"\$PROMPT_COMMAND\"
    "
    [ "$status" -eq 0 ]
    local count
    count=$(echo "${lines[-1]}" | grep -o '_tint_hook' | wc -l)
    [ "$count" -eq 1 ]
}

@test "hook reads .tint file" {
    local tmpdir
    tmpdir=$(mktemp -d)
    echo "solarized" > "$tmpdir/.tint"
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
    [[ "$output" =~ "solarized" ]]
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
    echo "solarized" > "$tmpdir/.tint"
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
    echo "solarized" > "$tmpdir/.tint"
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
    [[ "${lines[-1]}" =~ ^[[:space:]]*1$ ]]
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
    [[ "${lines[-1]}" = "reset" ]]
}

@test "hook strips inline comments" {
    local tmpdir
    tmpdir=$(mktemp -d)
    echo "solarized # my theme" > "$tmpdir/.tint"
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
    [[ "${lines[-1]}" = "solarized" ]]
}

@test "hook skips full-line comments" {
    local tmpdir
    tmpdir=$(mktemp -d)
    printf '# Project X\n# Dark theme\nsolarized\n' > "$tmpdir/.tint"
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
    [[ "${lines[-1]}" = "solarized" ]]
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
    [[ "${lines[-1]}" = "#002b36" ]]
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
    [[ "${lines[-1]}" = "#abc" ]]
}

@test "hook ignores comment-only .tint file" {
    local tmpdir
    tmpdir=$(mktemp -d)
    printf '# TODO: pick a theme\n# maybe solarized?\n' > "$tmpdir/.tint"
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
    [[ "${lines[-1]}" = "#002b36" ]]
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
    echo "solarized" > "$tmpdir/.tint"
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
    [[ "${lines[-1]}" =~ ^[[:space:]]*2$ ]]
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
    printf '#dark theme\nsolarized\n' > "$tmpdir/.tint"
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
    [[ "${lines[-1]}" = "solarized" ]]
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

@test "extra args still rejected for other commands" {
    run tint solarized extra
    [ "$status" -eq 1 ]
    [[ "$output" =~ "unexpected argument" ]]
}

@test "extra args rejected for completions subcommand" {
    run tint completions bash extra
    [ "$status" -eq 1 ]
    [[ "$output" =~ "unexpected argument" ]]
}
