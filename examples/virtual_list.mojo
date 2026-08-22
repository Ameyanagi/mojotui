"""Interactive 50k-row list with lazy rich-line generation."""

from std.collections import List as MojoList, Optional

from mojotui import (
    AnsiBackend,
    Application,
    Buffer,
    Color,
    Command,
    Constraint,
    InitResult,
    InputEvent,
    KeyEvent,
    Layout,
    Line,
    ListLineProvider,
    ListRenderContext,
    ListState,
    Rect,
    RuntimeAdapter,
    Size,
    Style,
    StylePatch,
    Subscription,
    SystemClock,
    TerminalApplicationHost,
    UpdateResult,
    VirtualList,
    detect_terminal_capabilities,
    render_line,
)
from std.utils import Variant


comptime ROW_COUNT = 50_000


struct LargeRowProvider(Copyable, ListLineProvider):
    def __init__(out self):
        pass

    def item_count(self) -> Int:
        return ROW_COUNT

    def line(self, context: ListRenderContext) raises -> Line:
        var content = String("result row ", context.index, " / generated preview")
        if context.selected:
            content += " ← cursor"
        var positions: MojoList[Int] = [0, 11]
        return Line.highlighted(
            content^,
            positions,
            StylePatch(
                foreground=Color.indexed(6),
                add_modifiers=Style.BOLD,
            ),
        )


struct LargeListModel(Copyable):
    var selection: ListState
    var page_rows: Int

    def __init__(out self, page_rows: Int):
        self.selection = ListState(selected=UInt(0))
        self.page_rows = max(page_rows, 1)


comptime LargeListMessage = Variant[KeyEvent, Size]


struct LargeListApplication(Application, Copyable):
    comptime Model = LargeListModel
    comptime Message = LargeListMessage
    comptime Effect = Bool

    var initial_page_rows: Int

    def __init__(out self, initial_page_rows: Int):
        self.initial_page_rows = max(initial_page_rows, 1)

    def init(mut self) raises -> InitResult[Self.Model, Self.Effect]:
        return InitResult[Self.Model, Self.Effect].ready(
            LargeListModel(self.initial_page_rows)
        )

    def update(
        mut self,
        mut model: Self.Model,
        var message: Self.Message,
    ) raises -> UpdateResult[Self.Effect]:
        if message.isa[Size]():
            model.page_rows = max(message[Size].height - 2, 1)
            return UpdateResult[Self.Effect].redraw_only()
        var key = message[KeyEvent].copy()
        if not key.is_activation():
            return UpdateResult[Self.Effect].unchanged()
        if key.code == KeyEvent.ESCAPE or (
            key.code == KeyEvent.CHARACTER and key.text == "q"
        ):
            return UpdateResult[Self.Effect].exit()
        if key.code == KeyEvent.DOWN:
            model.selection.next(ROW_COUNT)
        elif key.code == KeyEvent.UP:
            model.selection.previous(ROW_COUNT)
        elif key.code == KeyEvent.PAGE_DOWN:
            var selected = Int(
                model.selection.selected.value()
            ) if model.selection.selected else 0
            model.selection.select(
                UInt(min(selected + model.page_rows, ROW_COUNT - 1)), ROW_COUNT
            )
        elif key.code == KeyEvent.PAGE_UP:
            var selected = Int(
                model.selection.selected.value()
            ) if model.selection.selected else 0
            model.selection.select(UInt(max(selected - model.page_rows, 0)), ROW_COUNT)
        elif key.code == KeyEvent.HOME:
            model.selection.select(UInt(0), ROW_COUNT)
        elif key.code == KeyEvent.END:
            model.selection.select(UInt(ROW_COUNT - 1), ROW_COUNT)
        else:
            return UpdateResult[Self.Effect].unchanged()
        return UpdateResult[Self.Effect].redraw_only()

    def view(self, model: Self.Model, area: Rect, mut buffer: Buffer) raises:
        var regions = Layout.vertical(
            [Constraint.length(1), Constraint.fill(), Constraint.length(1)]
        ).split(area)
        if len(regions) < 3:
            return
        render_line(
            Line.from_text("50,000 lazy rows — only the viewport is formatted"),
            regions[0],
            buffer,
        )
        var state = model.selection.copy()
        VirtualList(LargeRowProvider(), scroll_padding=1).render(
            regions[1], buffer, state
        )
        render_line(
            Line.from_text("↑/↓ PgUp/PgDn Home/End move  q/Esc quit"),
            regions[2],
            buffer,
        )

    def on_input(
        self,
        model: Self.Model,
        var event: InputEvent,
    ) raises -> Optional[Self.Message]:
        if event.isa[KeyEvent]():
            var key = event[KeyEvent].copy()
            if key.is_activation():
                return LargeListMessage(key^)
        return None

    def on_resize(self, model: Self.Model, size: Size) raises -> Optional[Self.Message]:
        return LargeListMessage(size.copy())


struct LargeListAdapter(RuntimeAdapter):
    comptime ApplicationType = LargeListApplication

    def __init__(out self):
        pass

    def execute(mut self, var command: Command[Self.ApplicationType.Effect]) raises:
        pass

    def start(
        mut self,
        var subscription: Subscription[Self.ApplicationType.Effect],
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


def main() raises:
    var capabilities = detect_terminal_capabilities()
    var backend = AnsiBackend.from_terminal(capabilities=capabilities)
    var initial_page_rows = max(backend.area.height - 2, 1)
    var host = TerminalApplicationHost(
        LargeListAdapter(),
        LargeListApplication(initial_page_rows),
        SystemClock(),
        backend^,
    )
    host.run()
