"""PTY helper for testing tint_pick interactively.

Spawns bash in a pseudo-terminal, sources tint, calls tint_pick under set -eu,
feeds keystrokes, and captures output + exit code.

Usage: python3 test/pty_helper.py <key> [<key> ...]

Keys: right, left, up, down, enter, escape, q, h, j, k, l, single char,
      `resize:RxC` (set PTY size + send SIGWINCH),
      `signal:int` / `signal:term` (send SIGINT / SIGTERM to the picker).

Output (one key:value per line):
  exit:<code>                          tint_pick's exit code
  stdout:<theme-name>                  the theme tint_pick printed (or empty)
  stty_echo:on|off                     terminal echo state at tint_pick exit
  alt_screen_exited:yes|no             whether \\e[?1049l was emitted

When adding new output keys: extend this block AND add the parse line in
test/tint.bats's _pick helper.
"""

import fcntl
import os
import select
import signal
import shlex
import struct
import sys
import termios
import time

# Sentinel value for _tint_query_terminal_bg stub — must not appear in the palette.
STUB_BG = "#f0e1d2"

KEY_MAP = {
    "right": "\x1b[C",
    "left": "\x1b[D",
    "up": "\x1b[A",
    "down": "\x1b[B",
    "enter": "\r",
    "escape": "\x1b",
}

# Delay between keystrokes (seconds).
# The picker's _tint_esc_timeout is 0.01s (10ms) on Bash >= 4, and 1s on
# older Bash (< 4). A 20ms delay between keys stays well below the 10ms
# timeout in the fast case and is trivially safe in the slow case, so the
# read loop processes each key well within the effective timeout window.
KEY_DELAY = 0.02
# Escape key needs extra delay so bash's read -t timeout can fire
# and distinguish a bare Escape from the start of an arrow sequence.
ESCAPE_DELAY = 0.05
# Resize needs longer delay: SIGWINCH must be delivered, the picker loop
# must wake from its current read, and a full redraw must complete.
# _tint_read_timeout is 0.5s on Bash >= 4 and 1s on Bash 3.2 (macOS), but
# resize generally interrupts a read in flight rather than waiting for it
# to time out, so 0.3s suffices in practice on both versions.
RESIZE_DELAY = 0.3
# Termination signals (INT/TERM) need to cover the worst-case path:
#   1. signal delivery to the child
#   2. trap body execution (_tint_restore_terminal touches /dev/tty for
#      cursor/colors/stty/alt-screen)
#   3. loop check of _TINT_PICKER_INTERRUPTED on the next read iteration
#   4. bash function return
# Step 3 is gated by _tint_read_timeout: 0.5s on Bash >= 4, 1s on Bash 3.2
# (macOS). Sized to comfortably cover the slow case plus trap teardown
# margin so the test is non-flaky on both.
SIGNAL_DELAY = 1.5

def set_pty_size(fd, rows, cols):
    """Set the PTY window size via ioctl(TIOCSWINSZ)."""
    winsize = struct.pack("HHHH", rows, cols, 0, 0)
    fcntl.ioctl(fd, termios.TIOCSWINSZ, winsize)


def translate_key(name):
    if name in KEY_MAP:
        return KEY_MAP[name]
    if len(name) == 1:
        return name
    raise ValueError(f"Unknown key: {name}")


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 pty_helper.py <key> [<key> ...]", file=sys.stderr)
        sys.exit(2)

    keys = sys.argv[1:]

    # Create PTY pair
    master_fd, slave_fd = os.openpty()

    pid = os.fork()
    if pid == 0:
        # Child: become session leader, attach slave as controlling terminal
        os.close(master_fd)
        os.setsid()

        # Open slave to establish as controlling terminal
        slave_path = os.ttyname(slave_fd)
        ctrl_fd = os.open(slave_path, os.O_RDWR)
        os.close(ctrl_fd)

        # Redirect stdio to slave PTY
        os.dup2(slave_fd, 0)
        os.dup2(slave_fd, 1)
        os.dup2(slave_fd, 2)
        if slave_fd > 2:
            os.close(slave_fd)

        # Derive tint path from this script's location (not cwd)
        script_dir = os.path.dirname(os.path.abspath(__file__))
        tint_path = os.path.join(script_dir, "..", "tint")
        os.execvp("bash", [
            "bash", "-c",
            f"source {shlex.quote(tint_path)};"
            f" _tint_query_terminal_bg() {{ printf '%s' '{STUB_BG}'; }};"
            f" _tint_query_terminal_fg() {{ printf '%s' '#1a1b26'; }};"
            # EXIT trap checks stty echo state after tint_pick returns.
            # Runs regardless of exit code, so set -e cancels still report.
            f" trap '"
            f"  if stty -a </dev/tty 2>/dev/null | grep -qw -- -echo;"
            f"  then printf STTY_ECHO:off\\\\n;"
            f"  else printf STTY_ECHO:on\\\\n;"
            f"  fi"
            f" ' EXIT;"
            f" set -eu; tint_pick"
        ])
        # If exec fails
        os._exit(127)
    else:
        # Parent: feed keys and capture output
        os.close(slave_fd)

        # Drain PTY output continuously in a background thread to prevent
        # backpressure deadlocks when the child writes faster than we read
        # (e.g., full-frame redraws during scroll events).
        import threading
        output_chunks = []
        drain_done = threading.Event()

        def drain_output():
            while not drain_done.is_set():
                try:
                    ready, _, _ = select.select([master_fd], [], [], 0.01)
                    if ready:
                        chunk = os.read(master_fd, 65536)
                        if chunk:
                            output_chunks.append(chunk)
                        else:
                            break
                except OSError:
                    break

        drain_thread = threading.Thread(target=drain_output, daemon=True)
        drain_thread.start()

        # Wait for the picker to render initial state.
        # Poll for output rather than a fixed sleep — the picker writes
        # escape sequences as soon as it renders.
        deadline = time.monotonic() + 2.0
        while time.monotonic() < deadline:
            if output_chunks:
                break
            time.sleep(0.01)
        # Small settle time for the full frame to flush
        time.sleep(0.03)

        # Map of signal-name keys to actual signals. Used by the
        # `signal:<name>` key form so bats tests can drive interrupt-path
        # teardown (INT/TERM trap chain) without needing to fork their own
        # signaling logic.
        SIGNAL_KEYS = {
            "signal:int": signal.SIGINT,
            "signal:term": signal.SIGTERM,
        }

        # Send keys
        for key_name in keys:
            if key_name.startswith("resize:"):
                # resize:RxC — change PTY size and send SIGWINCH
                rows, cols = key_name.split(":")[1].split("x")
                set_pty_size(master_fd, int(rows), int(cols))
                os.kill(pid, signal.SIGWINCH)
                time.sleep(RESIZE_DELAY)
                continue
            if key_name in SIGNAL_KEYS:
                # Signal the child so the picker's INT/TERM trap fires.
                # The trap body sets _TINT_PICKER_INTERRUPTED; the read
                # loop notices on its next iteration and returns the code.
                os.kill(pid, SIGNAL_KEYS[key_name])
                time.sleep(SIGNAL_DELAY)
                continue
            seq = translate_key(key_name)
            os.write(master_fd, seq.encode())
            # After escape, wait longer so read -t timeout fires
            if key_name == "escape":
                time.sleep(ESCAPE_DELAY)
            else:
                time.sleep(KEY_DELAY)

        # Wait for child to finish
        _, status = os.waitpid(pid, 0)
        # Compatible with Python 3.8+ (os.waitstatus_to_exitcode requires 3.9)
        exit_code = os.WEXITSTATUS(status) if os.WIFEXITED(status) else -os.WTERMSIG(status)

        # Let drain thread collect remaining output, then stop it
        time.sleep(0.02)
        drain_done.set()
        drain_thread.join(timeout=1.0)

        output = b"".join(output_chunks)
        os.close(master_fd)

        # The output contains both /dev/tty rendering (ANSI escape codes,
        # OSC color queries, etc.) and stdout from tint_pick (the selected
        # theme name). Since both stdio and tty go to the same PTY, we
        # need to parse the theme name out by position.
        # tint_pick prints the name with printf '%s' (no newline) right
        # before return 0; it appears after the picker's final cursor-show.
        raw = output.decode("utf-8", errors="replace")

        # Extract the theme name from the raw output.
        # The picker outputs ANSI rendering to /dev/tty and the result via
        # printf '%s'. Both go to the same PTY fd, so we parse by position.
        import re

        # Look for the theme name after the last cursor-show sequence
        # (\x1b[?25h) since _tint_restore_terminal shows the cursor right
        # before the return. Strip OSC sequences and ANSI escapes first so
        # we don't match text inside terminal control output.
        show_cursor = "\x1b[?25h"
        cursor_pos = raw.rfind(show_cursor)
        if cursor_pos >= 0:
            after_cursor = raw[cursor_pos + len(show_cursor):]
            after_cursor = re.sub(r"\x1b\][^\x1b\x07]*(?:\x07|\x1b\\)", "", after_cursor)
            # CSI matches both standard `\x1b[<params><final>` and DEC private
            # mode `\x1b[?<params><final>` (e.g. `\x1b[?1049l` for alt-screen).
            after_cursor = re.sub(r"\x1b\[\??[0-9;]*[A-Za-z]", "", after_cursor)
            # Strip EXIT trap output (STTY_ECHO:...) so it doesn't match
            after_cursor = re.sub(r"STTY_ECHO:\w+", "", after_cursor)
            # Match theme name.  Intentionally narrower than tint's palette
            # validation regex ([a-zA-Z0-9][a-zA-Z0-9_-]*) — we restrict to
            # lowercase start + 2-char minimum to avoid false matches against
            # PTY control artifacts (digits, uppercase CSI remnants).  Safe
            # because every built-in theme name is lowercase and multi-char.
            result_match = re.search(r"[a-z][a-z0-9_-]+", after_cursor)
            stdout_result = result_match.group(0) if result_match else ""
        else:
            stdout_result = ""

        # Check stty echo state from EXIT trap output
        stty_match = re.search(r"STTY_ECHO:(on|off)", raw)
        stty_echo = stty_match.group(1) if stty_match else "unknown"

        # Did _tint_restore_terminal emit \e[?1049l? Lets tests prove the
        # picker actually reached the alt-screen-exit step of teardown
        # (vs. exiting earlier — e.g. via a stale trap that bypassed
        # _tint_restore_terminal). Search the raw PTY stream rather than
        # the post-strip text since the regex above removes it.
        alt_screen_exited = "yes" if "\x1b[?1049l" in raw else "no"

        print(f"exit:{exit_code}")
        print(f"stdout:{stdout_result}")
        print(f"stty_echo:{stty_echo}")
        print(f"alt_screen_exited:{alt_screen_exited}")


if __name__ == "__main__":
    main()
