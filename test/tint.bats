#!/usr/bin/env bats
# shellcheck disable=SC1091,SC2030,SC2031,SC2034

setup() {
    DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    PATH="$DIR:$PATH"

}

# Helper to source the library within a test (BATS runs tests in subshells)
_load_tint() {
    source "$DIR/tint"
}

# =============================================================================
# CLI
# =============================================================================

@test "tint --help shows usage" {
    run tint --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "terminal background color picker" ]]
}

@test "tint --version shows version" {
    run tint --version
    [ "$status" -eq 0 ]
    [[ "$output" =~ "tint" ]]
}

@test "tint --list shows colors" {
    run tint --list
    [ "$status" -eq 0 ]
    [[ "$output" =~ "#002b36".*"solarized" ]]
    [[ "$output" =~ "#2e3440".*"nord" ]]
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

@test "tint -q matches --query" {
    # Both may fail without a real terminal, so compare exit status and output
    run tint -q
    local short_status="$status"
    local short_output="$output"
    run tint --query
    [ "$short_status" -eq "$status" ]
    [ "$short_output" = "$output" ]
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

@test "tint random picks a palette color" {
    run tint random
    [ "$status" -eq 0 ]
    # Output should be "name #hex"
    [[ "$output" =~ ^[a-zA-Z0-9].+\ #[0-9a-fA-F]{6}$ ]]
}

@test "tint unknown-color fails" {
    run tint nonexistent
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Unknown color" ]]
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
    [[ "$output" =~ "lookup=#002b36" ]]
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
    [[ "$output" =~ "lookup=#002b36" ]]
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

@test "tint_lookup finds color" {
    # Source directly - sourcing via function scopes variables to that function
    source "$DIR/tint"
    local result
    result=$(tint_lookup "solarized")
    [ "$result" = "#002b36" ]
}

@test "tint_lookup fails for unknown" {
    _load_tint
    run tint_lookup "nonexistent"
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
    result=$(tint_resolve "nord")
    [ "$result" = "#2e3440" ]
}

@test "tint reset resets to default" {
    run tint reset
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
# Palette
# =============================================================================

@test "palette has expected colors" {
    # Source directly - sourcing via function scopes the variable to that function
    source "$DIR/tint"
    [[ "$TINT_PALETTE" =~ "vscode:#1e1e1e" ]]
    [[ "$TINT_PALETTE" =~ "solarized:#002b36" ]]
    [[ "$TINT_PALETTE" =~ "nord:#2e3440" ]]
}

@test "palette rejects hyphen-prefixed names" {
    # Names starting with - would be confused with CLI flags by cut/sed/grep
    source "$DIR/tint"
    export TINT_PALETTE=$'-badname:#abcdef\ngood:#123456'
    source "$DIR/tint"
    # Only the valid name should survive
    [ "$(_tint_palette_count)" -eq 1 ]
    [ "$(_tint_palette_get 1)" = "good:#123456" ]
}

@test "TINT_PALETTE env overrides default" {
    # Set env before sourcing so _tint_load_palette sees it as a string
    export TINT_PALETTE=$'custom:#abcdef'
    source "$DIR/tint"

    [ "$(_tint_palette_count)" -eq 1 ]
    [ "$(_tint_palette_get 1)" = "custom:#abcdef" ]
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

# =============================================================================
# Code Invariants
# =============================================================================

@test "_tint_query_raw is defined as subshell function" {
    # _tint_query_raw must use ( ) not { } so trap/stty changes are isolated.
    # Match the function definition: _tint_query_raw() (
    grep -qE '_tint_query_raw\(\)[[:space:]]*\(' "$DIR/tint" || {
        echo "_tint_query_raw is not a subshell function"
        return 1
    }
}

@test "tint_query has no bash-specific trap branching" {
    # With subshell isolation, there should be no BASH_VERSION checks or
    # trap -p / eval saved trap logic in the query functions.
    # Note: can't use `! grep` in bats — set -e is suppressed by `!`,
    # so failures would be silently ignored.
    local query_section
    query_section=$(grep -A30 '_tint_query_raw' "$DIR/tint")
    if echo "$query_section" | grep -q 'BASH_VERSION'; then
        echo "Found BASH_VERSION in _tint_query_raw"; return 1
    fi
    if echo "$query_section" | grep -q 'trap -p'; then
        echo "Found trap -p in _tint_query_raw"; return 1
    fi
    if echo "$query_section" | grep -q '_tq_saved_trap'; then
        echo "Found _tq_saved_trap in _tint_query_raw"; return 1
    fi
}

# =============================================================================
# Picker: Model
# =============================================================================

@test "model: down from 0" {
    source "$DIR/tint"
    _TINT_PK_IDX=0
    _TINT_PK_OLD_IDX=0
    local last_idx=9
    _tint_model_move_cursor down
    [ "$_TINT_PK_IDX" -eq 1 ]
    [ "$_TINT_PK_OLD_IDX" -eq 0 ]
}

@test "model: up from 0 wraps to last" {
    source "$DIR/tint"
    _TINT_PK_IDX=0
    _TINT_PK_OLD_IDX=0
    local last_idx=9
    _tint_model_move_cursor up
    [ "$_TINT_PK_IDX" -eq 9 ]
    [ "$_TINT_PK_OLD_IDX" -eq 0 ]
}

@test "model: down from last wraps to 0" {
    source "$DIR/tint"
    _TINT_PK_IDX=9
    _TINT_PK_OLD_IDX=0
    local last_idx=9
    _tint_model_move_cursor down
    [ "$_TINT_PK_IDX" -eq 0 ]
    [ "$_TINT_PK_OLD_IDX" -eq 9 ]
}

@test "model: up from middle" {
    source "$DIR/tint"
    _TINT_PK_IDX=5
    _TINT_PK_OLD_IDX=0
    local last_idx=9
    _tint_model_move_cursor up
    [ "$_TINT_PK_IDX" -eq 4 ]
    [ "$_TINT_PK_OLD_IDX" -eq 5 ]
}

@test "model: consecutive moves track OLD_IDX" {
    source "$DIR/tint"
    _TINT_PK_IDX=0
    _TINT_PK_OLD_IDX=0
    local last_idx=9
    _tint_model_move_cursor down
    _tint_model_move_cursor down
    _tint_model_move_cursor down
    [ "$_TINT_PK_IDX" -eq 3 ]
    [ "$_TINT_PK_OLD_IDX" -eq 2 ]
}

@test "scroll: all fit on screen" {
    source "$DIR/tint"
    _TINT_PK_IDX=0
    _TINT_PK_TOTAL=5
    _TINT_PK_VISIBLE=10
    _TINT_PK_WIN_START=0
    _TINT_PK_WIN_END=0
    _TINT_PK_RENDERED_ROWS=0
    _tint_update_scroll_window
    [ "$_TINT_PK_WIN_START" -eq 0 ]
    [ "$_TINT_PK_WIN_END" -eq 4 ]
    [ "$_TINT_PK_SCROLLED" -eq 0 ]
}

@test "scroll: initial window centers cursor" {
    source "$DIR/tint"
    _TINT_PK_IDX=15
    _TINT_PK_TOTAL=30
    _TINT_PK_VISIBLE=10
    _TINT_PK_WIN_START=0
    _TINT_PK_WIN_END=0
    _TINT_PK_RENDERED_ROWS=0
    _tint_update_scroll_window
    [ "$_TINT_PK_WIN_START" -eq 10 ]
    [ "$_TINT_PK_WIN_END" -eq 19 ]
    [ "$_TINT_PK_SCROLLED" -eq 1 ]
}

@test "scroll: initial window clamps to start" {
    source "$DIR/tint"
    _TINT_PK_IDX=2
    _TINT_PK_TOTAL=30
    _TINT_PK_VISIBLE=10
    _TINT_PK_WIN_START=0
    _TINT_PK_WIN_END=0
    _TINT_PK_RENDERED_ROWS=0
    _tint_update_scroll_window
    [ "$_TINT_PK_WIN_START" -eq 0 ]
    [ "$_TINT_PK_WIN_END" -eq 9 ]
    [ "$_TINT_PK_SCROLLED" -eq 0 ]
}

@test "scroll: initial window clamps to end" {
    source "$DIR/tint"
    _TINT_PK_IDX=28
    _TINT_PK_TOTAL=30
    _TINT_PK_VISIBLE=10
    _TINT_PK_WIN_START=0
    _TINT_PK_WIN_END=0
    _TINT_PK_RENDERED_ROWS=0
    _tint_update_scroll_window
    [ "$_TINT_PK_WIN_START" -eq 20 ]
    [ "$_TINT_PK_WIN_END" -eq 29 ]
    [ "$_TINT_PK_SCROLLED" -eq 1 ]
}

@test "scroll: cursor below window shifts down" {
    source "$DIR/tint"
    _TINT_PK_IDX=15
    _TINT_PK_TOTAL=30
    _TINT_PK_VISIBLE=10
    _TINT_PK_WIN_START=0
    _TINT_PK_WIN_END=9
    _TINT_PK_RENDERED_ROWS=5
    _tint_update_scroll_window
    [ "$_TINT_PK_WIN_END" -eq 15 ]
    [ "$_TINT_PK_WIN_START" -eq 6 ]
    [ "$_TINT_PK_SCROLLED" -eq 1 ]
}

@test "scroll: cursor above window shifts up" {
    source "$DIR/tint"
    _TINT_PK_IDX=3
    _TINT_PK_TOTAL=30
    _TINT_PK_VISIBLE=10
    _TINT_PK_WIN_START=10
    _TINT_PK_WIN_END=19
    _TINT_PK_RENDERED_ROWS=5
    _tint_update_scroll_window
    [ "$_TINT_PK_WIN_START" -eq 3 ]
    [ "$_TINT_PK_WIN_END" -eq 12 ]
    [ "$_TINT_PK_SCROLLED" -eq 1 ]
}

@test "scroll: cursor within window no scroll" {
    source "$DIR/tint"
    _TINT_PK_IDX=5
    _TINT_PK_TOTAL=30
    _TINT_PK_VISIBLE=10
    _TINT_PK_WIN_START=0
    _TINT_PK_WIN_END=9
    _TINT_PK_RENDERED_ROWS=5
    _tint_update_scroll_window
    [ "$_TINT_PK_WIN_START" -eq 0 ]
    [ "$_TINT_PK_WIN_END" -eq 9 ]
    [ "$_TINT_PK_SCROLLED" -eq 0 ]
}

@test "scroll: scrolled flag resets after no-scroll update" {
    source "$DIR/tint"
    _TINT_PK_IDX=15
    _TINT_PK_TOTAL=30
    _TINT_PK_VISIBLE=10
    _TINT_PK_WIN_START=0
    _TINT_PK_WIN_END=9
    _TINT_PK_RENDERED_ROWS=5
    _tint_update_scroll_window
    [ "$_TINT_PK_SCROLLED" -eq 1 ]
    # Now move within the window — scrolled should reset
    _TINT_PK_IDX=10
    _tint_update_scroll_window
    [ "$_TINT_PK_SCROLLED" -eq 0 ]
}

# Helper: set up minimal state for _tint_render_row tests
_setup_render_row() {
    source "$DIR/tint"
    _tint_names=(unused "solarized")
    _tint_hexes=(unused "#002b36")
    _tint_r=(0 0) _tint_g=(0 43) _tint_b=(0 54)
    _tint_fg=(30 97)
    _TINT_PK_TOTAL=2
    _TINT_PK_DEFAULT=0
    _TINT_PK_ORIGINAL_BG="#f0e1d2"
    _TINT_ROW_WIDTH=40
    _tint_buf=""
}

# =============================================================================
# Picker: View
# =============================================================================

@test "render: highlighted row has cursor marker" {
    _setup_render_row
    _tint_render_row 1 1
    [[ "$_tint_buf" == *"> "* ]]
}

@test "render: unhighlighted row has no marker" {
    _setup_render_row
    _tint_render_row 1 0
    [[ "$_tint_buf" != *"> "* ]]
    [[ "$_tint_buf" != *"* "* ]]
}

@test "render: default row has star marker" {
    _setup_render_row
    _TINT_PK_DEFAULT=1
    _tint_render_row 1 0
    [[ "$_tint_buf" == *"* "* ]]
}

@test "render: row 0 with original bg shows unchanged" {
    _setup_render_row
    _tint_render_row 0 0
    [[ "$_tint_buf" == *"(unchanged)"* ]]
}

@test "render: row 0 without original bg shows reset to default" {
    _setup_render_row
    _TINT_PK_ORIGINAL_BG=""
    _tint_render_row 0 0
    [[ "$_tint_buf" == *"(reset to default)"* ]]
}

@test "render: row includes color name" {
    _setup_render_row
    _tint_render_row 1 0
    [[ "$_tint_buf" == *"solarized"* ]]
}

@test "render: row includes hex value" {
    _setup_render_row
    _tint_render_row 1 0
    [[ "$_tint_buf" == *"002b36"* ]]
}

@test "render: highlighted row uses normal weight" {
    _setup_render_row
    _tint_render_row 1 1
    [[ "$_tint_buf" == *"48;2;"* ]]
    [[ "$_tint_buf" != *$'\e[2;'* ]]
}

@test "render: unhighlighted row uses dim" {
    _setup_render_row
    _tint_render_row 1 0
    [[ "$_tint_buf" == *$'\e[2;'* ]]
}

@test "render: row 0 default also gets star" {
    _setup_render_row
    _TINT_PK_DEFAULT=1
    _tint_render_row 0 0
    [[ "$_tint_buf" == *"* "* ]]
}

@test "scroll indicator: both arrows when scrolled mid" {
    source "$DIR/tint"
    _TINT_PK_WIN_START=5
    _TINT_PK_WIN_END=14
    _TINT_PK_TOTAL=30
    _tint_buf=""
    _tint_render_scroll_indicator
    [[ "$_tint_buf" == *"↑ 5 more"* ]]
    [[ "$_tint_buf" == *"↓ 15 more"* ]]
}

@test "scroll indicator: up arrow only at bottom" {
    source "$DIR/tint"
    _TINT_PK_WIN_START=20
    _TINT_PK_WIN_END=29
    _TINT_PK_TOTAL=30
    _tint_buf=""
    _tint_render_scroll_indicator
    [[ "$_tint_buf" == *"↑ 20 more"* ]]
    [[ "$_tint_buf" != *"↓"* ]]
}

@test "scroll indicator: down arrow only at top" {
    source "$DIR/tint"
    _TINT_PK_WIN_START=0
    _TINT_PK_WIN_END=9
    _TINT_PK_TOTAL=30
    _tint_buf=""
    _tint_render_scroll_indicator
    [[ "$_tint_buf" == *"↓ 20 more"* ]]
    [[ "$_tint_buf" != *"↑"* ]]
}

@test "scroll indicator: no indicator when all visible" {
    source "$DIR/tint"
    _TINT_PK_WIN_START=0
    _TINT_PK_WIN_END=4
    _TINT_PK_TOTAL=5
    _tint_buf=""
    _tint_render_scroll_indicator
    [[ "$_tint_buf" != *"↑"* ]]
    [[ "$_tint_buf" != *"↓"* ]]
}

# =============================================================================
# Picker: OSC 11 Guard
# =============================================================================

# Helper: run tint_pick in a PTY with tint_query stubbed to fail.
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
    cmd = cmd_prefix + "source '" + tint_dir + "/tint'; tint_query() { return 1; }; tint_pick 2>&1; echo EXIT:$?"
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
# Picker: Navigation
# =============================================================================

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
    [ "$PICK_STDOUT" = "#000000" ]  # black (first palette entry)
}

@test "picker: up wraps to last entry" {
    _pick up enter
    [ "$PICK_EXIT" -eq 0 ]
    [ "$PICK_STDOUT" = "#300a24" ]  # ubuntu (last palette entry)
}

@test "picker: down then up returns to start" {
    _pick down up enter
    [ "$PICK_EXIT" -eq 0 ]
    [ "$PICK_STDOUT" = "#f0e1d2" ]  # idx 0 = original background (stubbed by pty_helper)
}

@test "picker: multiple navigations" {
    _pick down down down enter
    [ "$PICK_EXIT" -eq 0 ]
    [ "$PICK_STDOUT" = "#282a36" ]  # third palette entry
}

@test "picker: j/k vim keys work" {
    _pick j j enter
    [ "$PICK_EXIT" -eq 0 ]
    [ "$PICK_STDOUT" = "#1e1e1e" ]  # vscode (second palette entry)
}

@test "picker: j/k scroll past visible window" {
    # Same as the arrow-key scroll tests but via vim bindings.
    # 23 j's from idx 0 → idx 23 (navy), then k k k → idx 20 (kanagawa).
    _pick j j j j j j j j j j \
         j j j j j j j j j j \
         j j j k k k enter
    [ "$PICK_EXIT" -eq 0 ]
    [ "$PICK_STDOUT" = "#1f1f28" ]  # kanagawa (palette entry 20)
}

@test "picker: right/left arrows work as alternate bindings" {
    # Right/left are mapped to down/up for convenience.
    _pick right right enter
    [ "$PICK_EXIT" -eq 0 ]
    [ "$PICK_STDOUT" = "#1e1e1e" ]  # vscode (second palette entry)
}

@test "picker: h/l vim keys work as alternate bindings" {
    # h/l are mapped to up/down for convenience.
    _pick l l enter
    [ "$PICK_EXIT" -eq 0 ]
    [ "$PICK_STDOUT" = "#1e1e1e" ]  # vscode (second palette entry)
}

@test "picker: scroll down past visible window" {
    # Navigate past the visible window (22 rows on 24-line PTY) to force
    # a scroll, exercising the full-redraw path in _tint_render_cursor_move.
    # 23 downs from idx 0 → idx 23 = palette entry 23 (navy).
    _pick down down down down down down down down down down \
         down down down down down down down down down down \
         down down down enter
    [ "$PICK_EXIT" -eq 0 ]
    [ "$PICK_STDOUT" = "#1b2838" ]  # navy (palette entry 23)
}

@test "picker: scroll up after scrolling down" {
    # Scroll down to idx 23, then back up 3 to idx 20 = palette entry 20.
    # Exercises the _TINT_PK_IDX < _TINT_PK_WIN_START branch in _tint_update_scroll_window.
    _pick down down down down down down down down down down \
         down down down down down down down down down down \
         down down down up up up enter
    [ "$PICK_EXIT" -eq 0 ]
    [ "$PICK_STDOUT" = "#1f1f28" ]  # kanagawa (palette entry 20)
}

@test "picker: down past last entry wraps to start" {
    # 30 items total (idx 0-29). 30 downs from idx 0 wraps back to idx 0.
    # Window must jump from bottom back to top (max-distance shift).
    _pick down down down down down down down down down down \
         down down down down down down down down down down \
         down down down down down down down down down down enter
    [ "$PICK_EXIT" -eq 0 ]
    [ "$PICK_STDOUT" = "#f0e1d2" ]  # idx 0 = unchanged (stubbed bg)
}

@test "picker: wrap to end then continue scrolling up" {
    # Up from idx 0 wraps to idx 29 (ubuntu), then 2 more ups → idx 27.
    # Verifies window state is correct after a max-distance jump, and
    # subsequent navigation scrolls correctly from the new position.
    _pick up up up enter
    [ "$PICK_EXIT" -eq 0 ]
    [ "$PICK_STDOUT" = "#1e2030" ]  # slate (palette entry 27)
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
    # _TINT_PK_RENDERED_ROWS isn't reset after erase, a second call
    # moves the cursor up again and clears lines above the picker.
    run bash -c "
        source '$DIR/tint'
        _TINT_PK_RENDERED_ROWS=5
        _TINT_PK_CURSOR_HIDDEN=0
        _TINT_PK_EXIT_REASON=cancel
        _TINT_PK_TRAPS_INSTALLED=0
        _TINT_PK_SAVED_STTY=''
        _tint_restore_terminal
        echo \$_TINT_PK_RENDERED_ROWS
    "
    [ "$status" -eq 0 ]
    [ "${lines[-1]}" = "0" ]
}

@test "picker: many keypresses do not hang under PTY backpressure" {
    # Full-frame redraw per keypress can fill the PTY buffer when
    # the master side isn't draining continuously, blocking the child's
    # write and preventing it from reading further keys — deadlock.
    # 15 down arrows exercises enough redraws to exceed a 4KB PTY buffer.
    run timeout 5 python3 "$DIR/test/pty_helper.py" \
        down down down down down down down down down down \
        down down down down down enter
    [ "$status" -eq 0 ]
    [[ "$output" == *"exit:0"* ]]
}

@test "picker: set -e does not kill script during navigation" {
    # Under set -e, [ test ] && cmd returns 1 when the test is false,
    # which kills the script. Render functions must use if/then instead.
    _pick down enter
    [ "$PICK_EXIT" -eq 0 ]
    [ "$PICK_STDOUT" = "#000000" ]
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
    cmd = "source '" + tint_dir + "/tint'; tint_query() { printf '%s' '#f0e1d2'; }; trap 'echo MYTRAP' EXIT; tint_pick >/dev/null; trap -p EXIT"
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
    # hex=$(tint_pick) must not include caller EXIT trap output.
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
    cmd = "source '" + tint_dir + "/tint'; tint_query() { printf '%s' '#f0e1d2'; }; trap 'echo LEAKED' EXIT; hex=$(tint_pick); echo HEX:$hex"
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
    # HEX value should be a clean 6-digit hex, not contaminated with trap output.
    # "LEAKED" will appear later (from the parent's EXIT trap), which is fine —
    # it just must not be part of the hex= capture.
    # Strip control characters (PTY adds \r, escape sequences) before matching.
    local clean
    clean=$(printf '%s' "$result" | sed 's/\x1b\[[^m]*m//g; s/\x1b\[[^a-zA-Z]*[a-zA-Z]//g; s/\r//g')
    [[ "$clean" =~ HEX:#[0-9a-fA-F]{6} ]]
    # Verify "LEAKED" is not embedded in the HEX value
    [[ ! "$clean" =~ HEX:#[0-9a-fA-F]{6}LEAKED ]]
}

@test "tint_pick subshell stdout clean when BASHPID unset (Bash 3.2 compat)" {
    # BASHPID doesn't exist on Bash 3.2, so ${BASHPID:-$$} always equals $$
    # even inside command substitution. Without a working subshell check,
    # hex=$(tint_pick) would save/restore the EXIT trap inside the subshell,
    # leaking trap output into the captured hex value. BASH_SUBSHELL (Bash 3.0+)
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
    cmd = "source '" + tint_dir + "/tint'; tint_query() { printf '%s' '#f0e1d2'; }; unset BASHPID; trap 'echo LEAKED' EXIT; hex=$(tint_pick); echo HEX:$hex"
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
    clean=$(printf '%s' "$result" | sed 's/\x1b\[[^m]*m//g; s/\x1b\[[^a-zA-Z]*[a-zA-Z]//g; s/\r//g')
    [[ "$clean" =~ HEX:#[0-9a-fA-F]{6} ]]
    # LEAKED must not be embedded in the hex capture
    [[ ! "$clean" =~ HEX:#[0-9a-fA-F]{6}LEAKED ]]
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

@test "color cache prevents redundant calls" {
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
