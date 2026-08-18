# Known limitations

- The project follows a pinned Mojo nightly and has no source-compatibility
  promise before 1.0.
- Hosted Linux CI has not run because this working directory has no Git remote.
- Windows has no terminal backend or event reactor.
- Inline rendering owns a fixed height. Writes through the same terminal
  descriptor while it is active break its cursor anchor.
- The input parser covers common ANSI, SGR mouse, focus, and bracketed-paste
  sequences. It does not negotiate every terminal keyboard protocol.
- The width table is pinned. A terminal configured with different emoji or
  ambiguous-width behavior can disagree with the renderer.
- The editor accepts UTF-8 and preserves BOM plus LF or CRLF. Other encodings
  need an application adapter.
- Syntax highlighting is an interface with stale-result protection; Mojotui
  ships no grammar collection or parser.
- OSC 52 supports bounded copy. Native clipboard reads and external clipboard
  change tracking require a host implementation of `Clipboard`.
- The runtime bridge is ready for a stable public Mojo task runtime. The project
  does not import the private unfinished AsyncRT package in the pinned toolchain.
- Editor undo history stays in memory and is not persisted across sessions.
- The initial widget set has no chart canvas or general constraint solver.
