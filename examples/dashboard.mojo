"""Interactive, portable system-monitor-style dashboard.

The metrics are deterministic demo data so the same example runs on macOS and
Linux without widening Mojotui's audited platform boundary. Press q or Ctrl-C
to quit, use the arrow keys to move through the process table, and use Tab or
the left/right arrows to change the selected tab.
"""

from std.collections import List as MojoList, Optional
from std.utils import Variant

from mojotui import (
    AdaptiveColor,
    Alignment,
    AnsiBackend,
    Application,
    Axis,
    Block,
    Buffer,
    Chart,
    Color,
    Command,
    Constraint,
    Dataset,
    Gauge,
    GraphKind,
    InitResult,
    InputEvent,
    KeyEvent,
    Layout,
    Line,
    LineGauge,
    List,
    ListItem,
    ListState,
    Marker,
    MouseCapture,
    Paragraph,
    ProfiledColor,
    Rect,
    Ratio,
    Row,
    RuntimeAdapter,
    Scrollbar,
    ScrollbarState,
    SessionOptions,
    Sparkline,
    Span,
    Style,
    StylePatch,
    Subscription,
    SystemClock,
    Table,
    TableState,
    Tabs,
    TerminalApplicationHost,
    TerminalCapabilities,
    Text,
    UpdateResult,
    detect_terminal_capabilities,
    render_line,
)


def accent_style(model: DashboardModel) -> Style:
    return Style(foreground=model.accent, modifiers=Style.BOLD)


def warning_style(model: DashboardModel) -> Style:
    return Style(foreground=model.warning, modifiers=Style.BOLD)


struct DashboardModel(Copyable):
    """All durable dashboard state, separate from widget descriptions."""

    var tick: Int
    var selected_tab: Int
    var processes: TableState
    var logs: ListState
    var cpu_history: MojoList[Int]
    var quit: Bool
    var capabilities: TerminalCapabilities
    var accent: Color
    var warning: Color
    var selected_foreground: Color

    def __init__(
        out self,
        capabilities: TerminalCapabilities = TerminalCapabilities.headless(),
    ) raises:
        self.tick = 0
        self.selected_tab = 0
        self.processes = TableState(selected=UInt(0))
        self.logs = ListState()
        self.cpu_history = [18, 24, 31, 27, 42, 38, 51, 46]
        self.quit = False
        self.capabilities = capabilities
        self.accent = AdaptiveColor(
            ProfiledColor.from_rgb(80, 40, 160),
            ProfiledColor.from_rgb(80, 200, 255),
        ).resolve(capabilities)
        self.warning = AdaptiveColor(
            ProfiledColor.from_rgb(150, 75, 0),
            ProfiledColor.from_rgb(255, 190, 70),
        ).resolve(capabilities)
        self.selected_foreground = AdaptiveColor(
            ProfiledColor.from_rgb(255, 255, 255),
            ProfiledColor.from_rgb(10, 20, 30),
        ).resolve(capabilities)


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
        Row.from_lines(
            [
                Line.from_text("mojo"),
                Line.from_text(String(21 + wobble) + "%"),
                Line.from_text("312M"),
            ]
        ),
        Row.from_lines(
            [
                Line.from_text("renderer"),
                Line.from_text(String(14 + (wobble * 2) % 7) + "%"),
                Line.from_text("108M"),
            ]
        ),
        Row.from_lines(
            [
                Line.from_text("indexer"),
                Line.from_text(String(8 + wobble // 2) + "%"),
                Line.from_text("86M"),
            ]
        ),
        Row.from_lines(
            [
                Line.from_text("compiler"),
                Line.from_text(String(5 + wobble) + "%"),
                Line.from_text("244M"),
            ]
        ),
        Row.from_lines(
            [
                Line.from_text("shell"),
                Line.from_text("2%"),
                Line.from_text("41M"),
            ]
        ),
    ]


def cpu_history_dataset(model: DashboardModel) raises -> Dataset:
    """Copy the rolling sparkline samples into numeric chart coordinates."""
    var xs = MojoList[Float64](capacity=len(model.cpu_history))
    var ys = MojoList[Float64](capacity=len(model.cpu_history))
    for index in range(len(model.cpu_history)):
        xs.append(Float64(index))
        ys.append(Float64(model.cpu_history[index]))
    return Dataset(
        xs,
        ys,
        name="CPU",
        kind=GraphKind.LINE,
        marker=Marker.BRAILLE,
        style=accent_style(model),
    )


def render_metric_blocks(model: DashboardModel, area: Rect, mut buffer: Buffer) raises:
    var columns = Layout.horizontal(
        [Constraint.fill(), Constraint.fill(), Constraint.fill()], spacing=1
    ).split(area)
    if len(columns) < 3:
        return

    var cpu_block = Block.bordered(Line.from_text(" CPU ", accent_style(model)))
    cpu_block.render(columns[0], buffer)
    var cpu_area = cpu_block.inner(columns[0])
    var cpu = cpu_percent(model)
    Gauge.labeled(
        Ratio.percent(cpu),
        Line.from_text(String(cpu) + "%", alignment=Alignment.CENTER),
        filled_style=accent_style(model),
    ).render(cpu_area, buffer)

    var memory_block = Block.bordered(Line.from_text(" Memory ", warning_style(model)))
    memory_block.render(columns[1], buffer)
    var memory_area = memory_block.inner(columns[1])
    var memory = memory_percent(model)
    LineGauge(Ratio.percent(memory), filled_style=warning_style(model)).render(
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
    Sparkline(history^, maximum=100, style=accent_style(model)).render(
        history_area, buffer
    )


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
        Row.from_lines(
            [
                Line.from_text("NAME"),
                Line.from_text("CPU"),
                Line.from_text("MEM"),
            ]
        ),
        header_style=StylePatch(add_modifiers=Style.BOLD | Style.UNDERLINED),
        selected_style=StylePatch(
            foreground=model.selected_foreground,
            background=model.accent,
            add_modifiers=Style.BOLD,
        ),
    )
    var table_area = Rect(inner.x, inner.y, max(inner.width - 1, 0), inner.height)
    table.render(table_area, buffer, model.processes)
    var scroll_state = ScrollbarState(
        content_length=row_count,
        position=model.processes.offset,
        viewport_length=max(inner.height - 1, 0),
    )
    Scrollbar(thumb_style=accent_style(model)).render(inner, buffer, scroll_state)


def render_activity_log(mut model: DashboardModel, area: Rect, mut buffer: Buffer):
    var block = Block.bordered(Line.from_text(" Activity "), padding_x=1)
    block.render(area, buffer)
    var inner = block.inner(area)
    var list = List(
        [
            ListItem.from_text("✓ renderer ready", accent_style(model)),
            ListItem.from_text("↻ frame diffed"),
            ListItem.from_text("⌁ input polled"),
            ListItem.from_text("界 width = 2"),
            ListItem.from_text("✓ terminal safe"),
        ],
        highlight_symbol="",
    )
    list.render(inner, buffer, model.logs)


def render_cpu_chart(model: DashboardModel, area: Rect, mut buffer: Buffer) raises:
    var block = Block.bordered(Line.from_text(" CPU trend "), padding_x=1)
    block.render(area, buffer)
    var inner = block.inner(area)
    if inner.is_empty():
        return

    var x_labels: MojoList[String] = ["0", "30", "60"]
    var y_labels: MojoList[String] = ["0", "100"]
    var datasets: MojoList[Dataset] = [cpu_history_dataset(model)]
    Chart(
        datasets^,
        Axis(0.0, 63.0, labels=x_labels),
        Axis(0.0, 100.0, labels=y_labels),
    ).render(inner, buffer)


def render_dashboard(mut model: DashboardModel, area: Rect, mut buffer: Buffer) raises:
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
                Span("Mojotui ", accent_style(model)),
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
        selected_style=StylePatch.from_style(accent_style(model)),
    ).render(header.inner(regions[0]), buffer)

    render_metric_blocks(model, regions[1], buffer)
    var body = Layout.horizontal(
        [Constraint.fill(2), Constraint.fill()], spacing=1
    ).split(regions[2])
    if len(body) == 2:
        render_process_table(model, body[0], buffer)
        if body[1].height >= 10:
            var side = Layout.vertical(
                [Constraint.fill(2), Constraint.fill()], spacing=1
            ).split(body[1])
            if len(side) == 2:
                render_cpu_chart(model, side[0], buffer)
                render_activity_log(model, side[1], buffer)
        else:
            render_activity_log(model, body[1], buffer)

    Paragraph(
        Text.from_line(
            Line(
                [
                    Span("↑/↓", accent_style(model)),
                    Span(" select  "),
                    Span("Tab/←/→", accent_style(model)),
                    Span(" view  "),
                    Span("q", warning_style(model)),
                    Span(" quit"),
                ]
            )
        ),
        wrap=False,
    ).render(regions[3], buffer)


def handle_key(mut model: DashboardModel, key: KeyEvent):
    if key.is_char("c") and key.modifiers.contains(KeyEvent.CONTROL):
        model.quit = True
    elif key.is_char("q"):
        model.quit = True
    elif key.code == KeyEvent.DOWN:
        model.processes.next(5)
    elif key.code == KeyEvent.UP:
        model.processes.previous(5)
    elif key.code == KeyEvent.TAB or key.code == KeyEvent.RIGHT:
        model.selected_tab = (model.selected_tab + 1) % 3
    elif key.code == KeyEvent.LEFT:
        model.selected_tab = (model.selected_tab + 2) % 3


struct DashboardTick(Copyable):
    def __init__(out self):
        pass


comptime DashboardMessage = Variant[KeyEvent, DashboardTick]


struct DashboardApplication(Application, Copyable):
    comptime Model = DashboardModel
    comptime Message = DashboardMessage
    comptime Effect = Bool

    var capabilities: TerminalCapabilities

    def __init__(
        out self,
        capabilities: TerminalCapabilities = TerminalCapabilities.headless(),
    ):
        self.capabilities = capabilities

    def init(mut self) raises -> InitResult[Self.Model, Self.Effect]:
        return InitResult[Self.Model, Self.Effect].ready(
            DashboardModel(self.capabilities)
        )

    def update(
        mut self, mut model: Self.Model, var message: Self.Message
    ) raises -> UpdateResult[Self.Effect]:
        if message.isa[KeyEvent]():
            handle_key(model, message[KeyEvent].copy())
            if model.quit:
                return UpdateResult[Self.Effect].exit(redraw=True)
        else:
            advance_dashboard(model)
        return UpdateResult[Self.Effect].redraw_only()

    def view(self, model: Self.Model, area: Rect, mut buffer: Buffer) raises:
        # Stateful widget viewport bookkeeping is frame-local here; durable
        # application state changes only in `update`.
        var render_model = model.copy()
        render_dashboard(render_model, area, buffer)

    def on_input(
        self, model: Self.Model, var event: InputEvent
    ) raises -> Optional[Self.Message]:
        if event.isa[KeyEvent]():
            return DashboardMessage(event[KeyEvent].copy())
        return None

    def on_tick(self, model: Self.Model, now_ns: Int) raises -> Optional[Self.Message]:
        return DashboardMessage(DashboardTick())


struct DashboardAdapter(RuntimeAdapter):
    """No-op boundary ready to be replaced by a general runtime adapter."""

    comptime ApplicationType = DashboardApplication

    def __init__(out self):
        pass

    def execute(mut self, var command: Command[Self.ApplicationType.Effect]) raises:
        pass

    def start(
        mut self, var subscription: Subscription[Self.ApplicationType.Effect]
    ) raises:
        pass

    def stop(mut self, id: StringSlice) raises:
        pass

    def take_messages(mut self) raises -> MojoList[Self.ApplicationType.Message]:
        return []

    def close(mut self) raises:
        pass

    def close_silently(mut self):
        pass


def run_dashboard() raises:
    var capabilities = detect_terminal_capabilities()
    var host = TerminalApplicationHost(
        DashboardAdapter(),
        DashboardApplication(capabilities),
        SystemClock(),
        AnsiBackend.from_terminal(capabilities=capabilities),
        options=SessionOptions(mouse=MouseCapture.CLICKS),
        tick_interval_ms=100,
    )
    host.run()


def main() raises:
    run_dashboard()
