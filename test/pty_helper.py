"""PTY helper for testing tint_pick interactively.

Spawns bash in a pseudo-terminal, sources tint, calls tint_pick under set -eu,
feeds keystrokes, and captures output + exit code.

Usage: python3 test/pty_helper.py <key> [<key> ...]

Keys: right, left, up, down, enter, escape, q, h, j, k, l (or any single char)

Output:
  exit:<code>
  stdout:<captured output>
"""

import os
import select
import shlex
import sys
import time

# Sentinel value for tint_query stub — must not appear in the palette.
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
# Escape key needs extra delay so bash's read -t timeout can fire
# and distinguish a bare Escape from the start of an arrow sequence.
KEY_DELAY = 0.05
ESCAPE_DELAY = 0.15


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
            f" tint_query() {{ printf '%s' '{STUB_BG}'; }};"
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
                    ready, _, _ = select.select([master_fd], [], [], 0.05)
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

        # Wait for the picker to render initial state
        time.sleep(0.3)

        # Send keys
        for key_name in keys:
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
        time.sleep(0.1)
        drain_done.set()
        drain_thread.join(timeout=1.0)

        output = b"".join(output_chunks)
        os.close(master_fd)

        # The output contains both /dev/tty rendering (escape codes, etc.)
        # and stdout from tint_pick (the hex color). Since both stdio and tty
        # go to the same PTY, we need to parse out the hex value.
        # tint_pick prints the hex with printf '%s' (no newline) right before
        # return 0. It will be after the final \n that the picker prints.
        raw = output.decode("utf-8", errors="replace")

        # Extract the hex color from the raw output.
        # The picker outputs ANSI rendering to /dev/tty and the result via
        # printf '%s'. Look for #XXXXXX pattern in the output.
        import re
        hex_match = re.findall(r"#[0-9a-fA-F]{6}", raw)

        # The selected color is the LAST hex value printed (the printf '%s'
        # output comes after all the rendering). But rendering also contains
        # hex values in the display. We need a smarter approach.
        #
        # tint_pick outputs the selected hex via printf '%s' on stdout.
        # The render function outputs to /dev/tty. In a PTY, both go to the
        # same fd. But the selected hex is printed AFTER the final newline
        # that the picker prints before returning.
        #
        # Strategy: split on the last \n from the picker, the hex follows it.
        # The picker does: printf '\n' >/dev/tty; then printf '%s' "$hex"
        # So we look for the pattern after the last newline.

        # Look for the hex after the last cursor-show sequence (\x1b[?25h)
        # since _tint_restore_terminal shows the cursor right before the return.
        # Strip OSC sequences first (\x1b]...\x1b\\ or \x1b]...\x07) so we
        # don't match hex values inside tint_set's terminal control output.
        show_cursor = "\x1b[?25h"
        cursor_pos = raw.rfind(show_cursor)
        if cursor_pos >= 0:
            after_cursor = raw[cursor_pos + len(show_cursor):]
            after_cursor = re.sub(r"\x1b\][^\x1b\x07]*(?:\x07|\x1b\\)", "", after_cursor)
            result_match = re.search(r"#[0-9a-fA-F]{6}", after_cursor)
            stdout_result = result_match.group(0) if result_match else ""
        else:
            stdout_result = ""

        # Check stty echo state from EXIT trap output
        stty_match = re.search(r"STTY_ECHO:(on|off)", raw)
        stty_echo = stty_match.group(1) if stty_match else "unknown"

        print(f"exit:{exit_code}")
        print(f"stdout:{stdout_result}")
        print(f"stty_echo:{stty_echo}")


if __name__ == "__main__":
    main()
