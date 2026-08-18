# API map

Import common types from `mojotui`. Subpackages remain available when an
application wants narrower imports.

| Task | Public API |
| --- | --- |
| Geometry and layout | `Point`, `Size`, `Rect`, `Constraint`, `Layout`, `Flex` |
| Cells and styling | `Cell`, `Color`, `Style`, `Buffer` |
| Rich text | `Span`, `Line`, `Text`, `render_line`, `render_text` |
| Stateless widgets | `Block`, `Paragraph`, `Gauge`, `LineGauge`, `Sparkline`, `Tabs`, `Clear` |
| Stateful widgets | `List`, `Table`, `Scrollbar`, `Editor`, `TextInput`, `TextArea` and their state types |
| Terminal output | `Terminal`, `AnsiBackend`, `InlineBackend`, `HeadlessBackend` |
| Terminal lifecycle | `TerminalSession`, `SessionOptions` |
| Input | `InputParser`, `InputEvent`, `KeyEvent`, `MouseEvent`, `PasteEvent` |
| Polling | `PosixReactor`, `ReactorPoll` |
| Application state | `Application`, `ApplicationRuntime`, `UpdateResult`, `MessageQueue` |
| Effects | `Command`, `Subscription`, `OperationTracker`, `CancellationToken` |
| Runtime bridge | `RuntimeAdapter`, `RuntimeScope` |
| Focus and input mapping | `FocusManager`, `Keymap`, `KeyChord`, `HitMap` |
| Editor data | `Document`, `SelectionSet`, `EditorEngine`, `EditorCommand` |
| Editor services | `LocalFileService`, `Clipboard`, `MemoryClipboard`, `Osc52Clipboard` |

Functions that can fail declare `raises`. The compiler checks trait constraints
and concrete associated types before execution.
