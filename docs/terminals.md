# Terminal and platform support

| Target | Status | Notes |
| --- | --- | --- |
| macOS ARM64 | Tested locally and in CI | PTY lifecycle, polling, resize, ANSI backend, and editor tests pass. |
| Linux x86-64 | Tested in CI | The complete locked check passes on `ubuntu-24.04`. |
| Linux ARM64 | Tested locally and in CI | The complete locked check passes on `ubuntu-24.04-arm`. |
| Windows | Unsupported | The current platform boundary requires POSIX descriptors, termios, poll, and ioctl. |

Mojotui expects a UTF-8 terminal with ANSI cursor movement, SGR styling, and the
standard private modes used for alternate screen, bracketed paste, focus, and
SGR mouse input. A terminal may ignore an unsupported optional mode.

The renderer uses its pinned Unicode width table rather than terminal queries.
Ambiguous-width characters default to one column; callers can request wide
ambiguous characters in the text-width functions.

OSC 52 clipboard writes are opt-in and capped by the provider's `max_bytes`.
Terminal emulators and multiplexers may disable OSC 52 or apply a smaller cap.
Mojotui does not query clipboard contents.

`SIGKILL` cannot run restoration code. PTY tests cover failures that allow the
process to execute its cleanup path, including Ctrl-C in the supplied probe.
