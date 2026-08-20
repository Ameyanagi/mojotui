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

## Color capabilities

Mojotui represents output support as monochrome, ANSI-16, ANSI-256, or
truecolor plus a light, dark, or unknown background appearance. ANSI and inline
backends detect conservative process-environment hints by default:

| Hint | Behavior |
| --- | --- |
| `NO_COLOR` is present | Monochrome profile; takes precedence over color hints |
| `COLORTERM=truecolor` or `24bit` | Truecolor profile |
| `TERM` contains `direct` | Truecolor profile |
| `TERM` contains `256color` | ANSI-256 profile |
| `TERM=dumb` | Monochrome profile |
| Recognized final `COLORFGBG` index | Selects light or dark appearance |
| Missing or malformed hints | ANSI-16 and dark |

Applications can pass an explicit `TerminalCapabilities` to any built-in
backend. This is recommended for tests, remote transports, multiplexers, and
applications that already have a user theme preference. Environment detection
does not send escape-sequence queries. A future OSC 11 query must be integrated
with the input reactor so its reply cannot be parsed as keyboard input.

`AdaptiveColor` respects a monochrome capability by resolving to the terminal's
default color. A directly constructed RGB `Style` is explicit application
intent and is not automatically removed by `NO_COLOR`.

The renderer uses its pinned Unicode width table rather than terminal queries.
Ambiguous-width characters default to one column; callers can request wide
ambiguous characters in the text-width functions.

OSC 52 clipboard writes are opt-in and capped by the provider's `max_bytes`.
Terminal emulators and multiplexers may disable OSC 52 or apply a smaller cap.
Mojotui does not query clipboard contents.

`SIGKILL` cannot run restoration code. PTY tests cover failures that allow the
process to execute its cleanup path, including Ctrl-C in the supplied probe.
