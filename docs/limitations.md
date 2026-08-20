# Known limitations

- The project follows a pinned Mojo nightly and has no source-compatibility
  promise before 1.0.
- Windows has no terminal backend or event reactor.
- Inline rendering follows terminal width but owns a fixed height. Writes
  through the same terminal descriptor while it is active break its cursor
  anchor.
- The input parser covers common ANSI, SGR mouse, focus, and bracketed-paste
  sequences. It does not negotiate every terminal keyboard protocol.
- Automatic color capability detection is intentionally conservative. It uses
  `NO_COLOR`, `COLORTERM`, `TERM`, and recognizable ANSI `COLORFGBG` values;
  it does not currently query the terminal background with OSC 11. Missing or
  malformed hints fall back to ANSI-16 on a dark background.
- A backend reports capabilities but does not rewrite arbitrary cell colors.
  Applications must resolve `ProfiledColor` or `AdaptiveColor` before building
  `Style`; directly supplied RGB colors remain RGB output by explicit intent.
- Width and word-wrap whitespace tables are pinned to Unicode 17.0.0. A
  terminal configured with different emoji or ambiguous-width behavior can
  disagree with the renderer.
- The editor accepts UTF-8 and preserves BOM plus LF or CRLF. Other encodings
  need an application adapter.
- Syntax highlighting is an interface with stale-result protection; Mojotui
  ships no grammar collection or parser.
- OSC 52 supports bounded copy. Native clipboard reads and external clipboard
  change tracking require a host implementation of `Clipboard`.
- The runtime bridge is ready for a stable public Mojo task runtime. The project
  does not import the private unfinished AsyncRT package in the pinned toolchain.
- The application host and event/editor/form surfaces remain experimental even
  though they are statically typed and covered by tests. See
  [API stability tiers](stability.md).
- Editor undo history stays in memory and is not persisted across sessions.
- Layout matches the documented Ratatui non-legacy fixture surface, but does not
  expose `Flex::Legacy`, negative overlap spacing, spacer rectangles, or a
  global solver cache. See [layout compatibility](layout-compatibility.md).
- The initial widget set has no chart canvas or arbitrary general-purpose
  constraint solver.
