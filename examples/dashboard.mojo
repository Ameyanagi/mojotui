"""Interactive, portable system-monitor-style dashboard.

The metrics are deterministic demo data so the same example runs on macOS and
Linux without widening Mojotui's audited platform boundary. Press q or Ctrl-C
to quit, use the arrow keys to move through the process table, and use Tab or
the left/right arrows to change the selected tab.
"""

from std.collections import List as MojoList

from mojotui import (
    Alignment,
    AnsiBackend,
    Block,
    Buffer,
    Color,
    Constraint,
    Gauge,
    InputParser,
    KeyEvent,
    Layout,
    Line,
    LineGauge,
    List,
    ListItem,
    ListState,
    Paragraph,
    PosixReactor,
    Rect,
    Row,
    Scrollbar,
    ScrollbarState,
    SessionOptions,
    Sparkline,
    Span,
    Style,
    Table,
    TableState,
    Tabs,
    Terminal,
    TerminalSession,
    Text,
    render_line,
)


def accent_style() -> Style:
    return Style(foreground=Color.rgb(80, 200, 255), modifiers=Style.BOLD)


def warning_style() -> Style:
    return Style(foreground=Color.rgb(255, 190, 70), modifiers=Style.BOLD)


struct DashboardModel(Copyable):
    """All durable dashboard state, separate from widget descriptions."""

    var tick: Int
    var selected_tab: Int
    var processes: TableState
    var logs: ListState
    var cpu_history: MojoList[Int]
    var quit: Bool

    def __init__(out self):
        self.tick = 0
        self.selected_tab = 0
        self.processes = TableState(selected=0)
        self.logs = ListState()
        self.cpu_history = [18, 24, 31, 27, 42, 38, 51, 46]
        self.quit = False


def cpu_percent(model: DashboardModel) -> Int:
    return 18 + (model.tick * 7) % 68


def memory_percent(model: DashboardModel) -> Int:
    return 46 + (model.tick * 3) % 24


def advance_dashboard(mut model: DashboardModel):
    """Advance deterministic demo metrics by one timer tick."""
    model.tick = (model.tick + 1) % 1_000_000
    model.cpu_history.append(cpu_percent(model))
    if len(model.cpu_history) > 64:
        _ = model.cpu_history.pop(0)


def process_rows(model: DashboardModel) -> MojoList[Row]:
    var wobble = model.tick % 9
    return [
        Row(
            [
                Line.from_text("mojo"),
                Line.from_text(String(21 + wobble) + "%"),
                Line.from_text("312M"),
            ]
        ),
        Row(
            [
                Line.from_text("renderer"),
                Line.from_text(String(14 + (wobble * 2) % 7) + "%"),
                Line.from_text("108M"),
            ]
        ),
        Row(
            [
                Line.from_text("indexer"),
                Line.from_text(String(8 + wobble // 2) + "%"),
                Line.from_text("86M"),
            ]
        ),
        Row(
            [
                Line.from_text("compiler"),
                Line.from_text(String(5 + wobble) + "%"),
                Line.from_text("244M"),
            ]
        ),
        Row(
            [
                Line.from_text("shell"),
                Line.from_text("2%"),
                Line.from_text("41M"),
            ]
        ),
    ]


def render_metric_blocks(model: DashboardModel, area: Rect, mut buffer: Buffer):
    var columns = Layout.horizontal(
        [Constraint.fill(), Constraint.fill(), Constraint.fill()], spacing=1
    ).split(area)
    if len(columns) < 3:
        return

    var cpu_block = Block.bordered(Line.from_text(" CPU ", accent_style()))
    cpu_block.render(columns[0], buffer)
    var cpu_area = cpu_block.inner(columns[0])
    var cpu = cpu_percent(model)
    Gauge.labeled(
        Float64(cpu) / 100.0,
        Line.from_text(String(cpu) + "%", alignment=Alignment.CENTER),
        filled_style=accent_style(),
    ).render(cpu_area, buffer)

    var memory_block = Block.bordered(Line.from_text(" Memory ", warning_style()))
    memory_block.render(columns[1], buffer)
    var memory_area = memory_block.inner(columns[1])
    var memory = memory_percent(model)
    LineGauge(Float64(memory) / 100.0, filled_style=warning_style()).render(
        memory_area, buffer
    )
    if memory_area.height > 1:
        render_line(
            Line.from_text(String(memory) + "% of 16 GiB", alignment=Alignment.CENTER),
            Rect(memory_area.x, memory_area.y + 1, memory_area.width, 1),
            buffer,
        )

    var history_block = Block.bordered(Line.from_text(" CPU history "))
    history_block.render(columns[2], buffer)
    var history_area = history_block.inner(columns[2])
    var history = model.cpu_history.copy()
    Sparkline(history^, maximum=100, style=accent_style()).render(history_area, buffer)


def render_process_table(mut model: DashboardModel, area: Rect, mut buffer: Buffer):
    var block = Block.bordered(Line.from_text(" Processes "), padding_x=1)
    block.render(area, buffer)
    var inner = block.inner(area)
    if inner.is_empty():
        return
    var rows = process_rows(model)
    var row_count = len(rows)
    var table = Table.with_header(
        rows^,
        [
            Constraint.percentage(55),
            Constraint.percentage(20),
            Constraint.fill(),
        ],
        Row(
            [
                Line.from_text("NAME"),
                Line.from_text("CPU"),
                Line.from_text("MEM"),
            ]
        ),
        header_style=Style(modifiers=Style.BOLD | Style.UNDERLINED),
        selected_style=Style(
            foreground=Color.rgb(10, 20, 30),
            background=Color.rgb(80, 200, 255),
            modifiers=Style.BOLD,
        ),
    )
    var table_area = Rect(inner.x, inner.y, max(inner.width - 1, 0), inner.height)
    table.render(table_area, buffer, model.processes)
    var scroll_state = ScrollbarState(
        content_length=row_count,
        position=model.processes.offset,
        viewport_length=max(inner.height - 1, 0),
    )
    Scrollbar(thumb_style=accent_style()).render(inner, buffer, scroll_state)


def render_activity_log(mut model: DashboardModel, area: Rect, mut buffer: Buffer):
    var block = Block.bordered(Line.from_text(" Activity "), padding_x=1)
    block.render(area, buffer)
    var inner = block.inner(area)
    var list = List(
        [
            ListItem.from_text("✓ renderer ready", accent_style()),
            ListItem.from_text("↻ frame diffed"),
            ListItem.from_text("⌁ input polled"),
            ListItem.from_text("界 width = 2"),
            ListItem.from_text("✓ terminal safe"),
        ],
        highlight_symbol="",
    )
    list.render(inner, buffer, model.logs)


def render_dashboard(mut model: DashboardModel, area: Rect, mut buffer: Buffer):
    """Render one dashboard frame without I/O or hidden global state."""
    if area.width < 40 or area.height < 14:
        Paragraph.with_block(
            Text.from_line(Line.from_text("Resize to at least 40×14")),
            Block.bordered(Line.from_text(" Mojotui "), padding_x=1),
        ).render(area, buffer)
        return

    var regions = Layout.vertical(
        [
            Constraint.length(3),
            Constraint.length(6),
            Constraint.fill(),
            Constraint.length(1),
        ]
    ).split(area)

    var header = Block.bordered(
        Line(
            [
                Span("Mojotui ", accent_style()),
                Span("dashboard"),
            ]
        ),
        padding_x=1,
    )
    header.render(regions[0], buffer)
    Tabs(
        [
            Line.from_text("Overview"),
            Line.from_text("Processes"),
            Line.from_text("Runtime"),
        ],
        selected=model.selected_tab,
        selected_style=accent_style(),
    ).render(header.inner(regions[0]), buffer)

    render_metric_blocks(model, regions[1], buffer)
    var body = Layout.horizontal(
        [Constraint.fill(2), Constraint.fill()], spacing=1
    ).split(regions[2])
    if len(body) == 2:
        render_process_table(model, body[0], buffer)
        render_activity_log(model, body[1], buffer)

    Paragraph(
        Text.from_line(
            Line(
                [
                    Span("↑/↓", accent_style()),
                    Span(" select  "),
                    Span("Tab/←/→", accent_style()),
                    Span(" view  "),
                    Span("q", warning_style()),
                    Span(" quit"),
                ]
            )
        ),
        wrap=False,
    ).render(regions[3], buffer)


def handle_key(mut model: DashboardModel, key: KeyEvent):
    if (
        key.code == KeyEvent.CHARACTER
        and key.text == "c"
        and (key.modifiers & KeyEvent.CONTROL) != 0
    ):
        model.quit = True
    elif key.code == KeyEvent.CHARACTER and key.text == "q":
        model.quit = True
    elif key.code == KeyEvent.DOWN:
        model.processes.next(5)
    elif key.code == KeyEvent.UP:
        model.processes.previous(5)
    elif key.code == KeyEvent.TAB or key.code == KeyEvent.RIGHT:
        model.selected_tab = (model.selected_tab + 1) % 3
    elif key.code == KeyEvent.LEFT:
        model.selected_tab = (model.selected_tab + 2) % 3


def run_dashboard() raises:
    var session = TerminalSession(options=SessionOptions(mouse_capture=True))
    var terminal = Terminal(AnsiBackend.from_terminal())
    var reactor = PosixReactor()
    var parser = InputParser()
    var model = DashboardModel()

    while not model.quit:
        var area = terminal.viewport()
        var frame = Buffer(area)
        render_dashboard(model, area, frame)
        terminal.present(frame)

        var observation = reactor.wait(100)
        if observation.failed:
            raise Error("terminal reactor failed")
        if observation.hangup:
            break
        if observation.resized:
            _ = terminal.backend.refresh_viewport()
        if observation.input_ready:
            var events = reactor.read_events(parser)
            for index in range(len(events)):
                if events[index].isa[KeyEvent]():
                    handle_key(model, events[index][KeyEvent].copy())
        elif observation.timer_elapsed and parser.pending_byte_count() > 0:
            var events = parser.flush_escape()
            for index in range(len(events)):
                if events[index].isa[KeyEvent]():
                    handle_key(model, events[index][KeyEvent].copy())
        if observation.timer_elapsed:
            advance_dashboard(model)

    session.close()


def main() raises:
    run_dashboard()
