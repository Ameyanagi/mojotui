# Custom widgets

A stateless widget implements `Widget` and renders into the supplied area. The
buffer clips writes, but the widget should intersect expensive work with the
visible region before iterating.

```mojo
from mojotui import Buffer, Cell, Rect, Widget


struct Fill(Widget, Copyable):
    var cell: Cell

    def __init__(out self, cell: Cell):
        self.cell = cell.copy()

    def render(self, area: Rect, mut buffer: Buffer):
        buffer.fill(buffer.area.intersection(area), self.cell)
```

Keep mutable interaction state in a separate type and implement
`StatefulWidget` when rendering needs it:

```mojo
from mojotui import Buffer, Cell, Point, Rect, StatefulWidget


struct CounterState(Copyable):
    var value: Int

    def __init__(out self, value: Int = 0):
        self.value = value


struct Counter(StatefulWidget, Copyable):
    comptime State = CounterState

    def render(
        self,
        area: Rect,
        mut buffer: Buffer,
        mut state: CounterState,
    ) raises:
        if not area.is_empty():
            _ = buffer.set_cell(
                Point(area.x, area.y),
                Cell("+" if state.value > 0 else "0"),
            )
```

The application owns `CounterState` and decides when to change it. Widgets do
not read terminal state, clocks, or files during rendering. This keeps headless
snapshots deterministic.

Static dispatch means a generic function accepts `W: Widget` or
`W: StatefulWidget`; Mojotui does not box custom widgets into a runtime list.
Use an application-specific `Variant` when a finite runtime list is necessary.
