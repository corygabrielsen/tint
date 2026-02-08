#!/usr/bin/env bats

setup() {
    DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    PATH="$DIR:$PATH"
}

# Helper to source the library within a test (BATS runs tests in subshells)
_load_tint() {
    source "$DIR/tint"
}

# =============================================================================
# CLI Tests
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
    [[ "$output" =~ "dracula:#282a36" ]]
    [[ "$output" =~ "nord:#2e3440" ]]
}

@test "tint random picks a palette color" {
    run tint random
    [ "$status" -eq 0 ]
    # Output should be "name #hex"
    [[ "$output" =~ ^[a-zA-Z0-9].+\ #[0-9a-fA-F]{6}$ ]]
}

@test "tint --names shows only names" {
    run tint --names
    [ "$status" -eq 0 ]
    [[ "$output" =~ "dracula" ]]
    [[ ! "$output" =~ "#282a36" ]]
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
    # Regression: POSIX fallback in _tint_is_main only matched basename "tint",
    # so symlinks or renamed copies silently did nothing.
    tmpdir=$(mktemp -d)
    ln -s "$DIR/tint" "$tmpdir/my-bg-picker"
    run "$tmpdir/my-bg-picker" --version
    rm -rf "$tmpdir"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "tint" ]]
}

@test "tint sourced from POSIX script does not re-exec caller" {
    # Regression: POSIX fallback must not trigger _tint_main when sourced
    # from a #!/bin/sh script (where $0 is the calling script, not a shell).
    tmpdir=$(mktemp -d)
    cat > "$tmpdir/caller.sh" << INNEREOF
#!/bin/sh
echo "pre_source"
. "$DIR/tint"
echo "post_source"
echo "lookup=\$(tint_lookup dracula)"
INNEREOF
    chmod +x "$tmpdir/caller.sh"
    run "$tmpdir/caller.sh"
    rm -rf "$tmpdir"
    [ "$status" -eq 0 ]
    # "pre_source" should appear exactly once (not re-exec'd)
    local count
    count=$(echo "$output" | grep -c "pre_source")
    [ "$count" -eq 1 ]
    [[ "$output" =~ "lookup=#282a36" ]]
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
echo "lookup=\$(tint_lookup dracula)"
INNEREOF
    chmod +x "$tmpdir/caller.sh"
    run "$tmpdir/caller.sh" --version
    rm -rf "$tmpdir"
    [ "$status" -eq 0 ]
    # Should see caller output, NOT tint version info
    [[ "$output" =~ "caller_only" ]]
    [[ ! "$output" =~ "tint " ]]
    [[ "$output" =~ "lookup=#282a36" ]]
}

# =============================================================================
# Library Tests
# =============================================================================

@test "tint_lookup finds color" {
    # Source directly - sourcing via function scopes variables to that function
    source "$DIR/tint"
    local result
    result=$(tint_lookup "dracula")
    [ "$result" = "#282a36" ]
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

@test "tint_resolve handles none" {
    _load_tint
    run tint_resolve "none"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "tint_resolve fails for invalid" {
    _load_tint
    run tint_resolve "not-a-color"
    [ "$status" -eq 1 ]
}

@test "tint_resolve rejects invalid hex" {
    _load_tint
    run tint_resolve "#12345"  # 5 digits
    [ "$status" -eq 1 ]
}

@test "palette has expected colors" {
    # Source directly - sourcing via function scopes the variable to that function
    source "$DIR/tint"
    [[ "$TINT_PALETTE" =~ "vscode:#1e1e1e" ]]
    [[ "$TINT_PALETTE" =~ "dracula:#282a36" ]]
    [[ "$TINT_PALETTE" =~ "nord:#2e3440" ]]
}

@test "palette rejects hyphen-prefixed names" {
    # CR-002: names starting with - would be confused with CLI flags
    source "$DIR/tint"
    export TINT_PALETTE=$'-badname:#abcdef\ngood:#123456'
    source "$DIR/tint"
    # Only the valid name should survive
    [ "$(_tint_palette_count)" -eq 1 ]
    [ "$(_tint_palette_get 1)" = "good:#123456" ]
}

@test "_tint_query_raw is defined as subshell function" {
    # _tint_query_raw must use ( ) not { } so trap/stty changes are isolated.
    # Match the function definition: _tint_query_raw() (
    grep -qE '_tint_query_raw\(\)[[:space:]]*\(' "$DIR/tint" || {
        echo "_tint_query_raw is not a subshell function"
        return 1
    }
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



@test "TINT_PALETTE env overrides default" {
    # Set env before sourcing so _tint_load_palette sees it as a string
    export TINT_PALETTE=$'custom:#abcdef'
    source "$DIR/tint"

    [ "$(_tint_palette_count)" -eq 1 ]
    [ "$(_tint_palette_get 1)" = "custom:#abcdef" ]
}
