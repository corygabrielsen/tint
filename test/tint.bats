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
    [[ "$output" =~ "dracula:#282a36" ]]
    [[ "$output" =~ "nord:#2e3440" ]]
}

@test "tint --names shows only names" {
    run tint --names
    [ "$status" -eq 0 ]
    [[ "$output" =~ "dracula" ]]
    [[ ! "$output" =~ "#282a36" ]]
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
    # Regression: POSIX fallback in _tint_is_main only matched basename "tint",
    # so symlinks or renamed copies silently did nothing.
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
    # Regression: env_setup without '; ' suffix must not break command parsing
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
    # Validate the exact Try: printf command including proper escaping
    [[ "$UNSUPPORTED_OUTPUT" =~ "Try: printf '\\033]11;?\\033\\\\'" ]]
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

@test "TINT_PALETTE env overrides default" {
    # Set env before sourcing so _tint_load_palette sees it as a string
    export TINT_PALETTE=$'custom:#abcdef'
    source "$DIR/tint"

    [ "$(_tint_palette_count)" -eq 1 ]
    [ "$(_tint_palette_get 1)" = "custom:#abcdef" ]
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
# Picker
# =============================================================================

# Helper: run tint_pick in a PTY with simulated keystrokes
# Usage: _pick <key> [<key> ...]
# Sets: PICK_EXIT (exit code), PICK_STDOUT (captured output)
_pick() {
    local result
    result=$(python3 "$DIR/test/pty_helper.py" "$@" 2>/dev/null)
    PICK_EXIT=$(echo "$result" | grep '^exit:' | cut -d: -f2)
    PICK_STDOUT=$(echo "$result" | grep '^stdout:' | cut -d: -f2-)
}

@test "picker: navigate right and select" {
    _pick right enter
    [ "$PICK_EXIT" -eq 0 ]
    [ "$PICK_STDOUT" = "#1e1e1e" ]  # vscode (first palette entry)
}

@test "picker: navigate left wraps to last entry" {
    _pick left enter
    [ "$PICK_EXIT" -eq 0 ]
    [ "$PICK_STDOUT" = "#300a24" ]  # ubuntu (last palette entry)
}

@test "picker: right then left returns to start" {
    _pick right left enter
    [ "$PICK_EXIT" -eq 0 ]
    [ "$PICK_STDOUT" = "#f0e1d2" ]  # idx 0 = original background (stubbed by pty_helper)
}

@test "picker: multiple navigations" {
    _pick right right right enter
    [ "$PICK_EXIT" -eq 0 ]
    [ "$PICK_STDOUT" = "#2e3440" ]  # nord (third palette entry)
}

@test "picker: vim keys work" {
    _pick l l enter
    [ "$PICK_EXIT" -eq 0 ]
    [ "$PICK_STDOUT" = "#282a36" ]  # dracula (second palette entry)
}

@test "picker: cancel with escape" {
    _pick right escape
    [ "$PICK_EXIT" -eq 1 ]
    [ "$PICK_STDOUT" = "" ]
}

@test "picker: cancel with q" {
    _pick right q
    [ "$PICK_EXIT" -eq 1 ]
    [ "$PICK_STDOUT" = "" ]
}

@test "picker: set -e does not kill script during navigation" {
    # Regression test: _tint_render used [ test ] && cmd which returns 1
    # under set -e when the test is false, killing the script.
    _pick right enter
    [ "$PICK_EXIT" -eq 0 ]
    [ "$PICK_STDOUT" = "#1e1e1e" ]
}

@test "picker tests work from non-repo directory" {
    # CR-009: pty_helper.py uses source ./tint which assumes cwd is repo root.
    # Tests should pass even when invoked from a different directory.
    cd /tmp
    run bats "$DIR/test/tint.bats" -f "picker: navigate right and select"
    [ "$status" -eq 0 ]
}

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
    # CR-006: BASH_VERSION can leak via environment into non-bash shells.
    # tint_pick must use subshell array syntax test, not simple presence checks.
    run env BASH_VERSION=5 dash -c ". '$DIR/tint'; tint_pick"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "requires bash" ]]
    # Must NOT contain "Bad substitution" (the crash this prevents)
    [[ ! "$output" =~ "Bad substitution" ]]
}

@test "tint_pick rejects non-bash shell with spoofed BASH_VERSINFO" {
    # CR-009: BASH_VERSINFO can be set as plain env var, fooling presence checks.
    # Only real bash can parse array subscript syntax like ${BASH_VERSINFO[0]}.
    run env BASH_VERSINFO=5 dash -c ". '$DIR/tint'; tint_pick"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "requires bash" ]]
    [[ ! "$output" =~ "Bad substitution" ]]
}

@test "tint_pick preserves caller EXIT trap in direct call" {
    # CR-005/CR-008: tint_pick must restore caller's EXIT trap when called
    # directly (not in command substitution).
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
    # CR-005: hex=$(tint_pick) must not include caller EXIT trap output.
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
    # CR-010: BASHPID doesn't exist on Bash 3.2, so ${BASHPID:-$$} always
    # equals $$. This breaks subshell detection, causing EXIT trap to be
    # saved/restored inside command substitution, corrupting stdout.
    # The fix uses BASH_SUBSHELL (available since Bash 3.0) instead.
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
