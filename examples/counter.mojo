"""Ratatui's counter tutorial using Mojotui's typed application convenience."""

from std.collections import Optional

from mojotui import (
    Alignment,
    Application,
    Block,
    Buffer,
    Color,
    InitResult,
    InputEvent,
    KeyEvent,
    Line,
    Paragraph,
    Rect,
    Span,
    Text,
    UpdateResult,
    run,
)


struct CounterModel(Copyable):
    var counter: Int

    def __init__(out self):
        self.counter = 0


def draw_counter(model: CounterModel, area: Rect, mut buffer: Buffer):
    var title = Line.raw(" Counter App Tutorial ", Alignment.CENTER).bold()
    var instructions = Line(
        [
            Span(" Decrement "),
            Span("<Left>").fg(Color.BLUE).bold(),
            Span(" Increment "),
            Span("<Right>").fg(Color.BLUE).bold(),
            Span(" Quit "),
            Span("<Q> ").fg(Color.BLUE).bold(),
        ],
        alignment=Alignment.CENTER,
    )
    var block = Block.bordered(title, border_type=Block.THICK).title_bottom(
        instructions
    )
    block.render(area, buffer)

    var counter_line = Line(
        [
            Span("Value: "),
            Span(String(model.counter)).fg(Color.YELLOW),
        ],
        alignment=Alignment.CENTER,
    )
    Paragraph(Text.from_line(counter_line)).render(block.inner(area), buffer)


struct CounterApp(Application, Copyable):
    comptime Model = CounterModel
    comptime Message = KeyEvent
    comptime Effect = Bool

    def __init__(out self):
        pass

    def init(mut self) raises -> InitResult[Self.Model, Self.Effect]:
        return InitResult[Self.Model, Self.Effect].ready(CounterModel())

    def update(
        mut self, mut model: Self.Model, var message: Self.Message
    ) raises -> UpdateResult[Self.Effect]:
        if message.kind != KeyEvent.PRESS:
            return UpdateResult[Self.Effect].unchanged()
        if message.is_char("q"):
            return UpdateResult[Self.Effect].exit(redraw=True)
        if message.code == KeyEvent.LEFT:
            model.counter -= 1
        elif message.code == KeyEvent.RIGHT:
            model.counter += 1
        return UpdateResult[Self.Effect].redraw_only()

    def view(self, model: Self.Model, area: Rect, mut buffer: Buffer) raises:
        draw_counter(model, area, buffer)

    def on_input(
        self, model: Self.Model, var event: InputEvent
    ) raises -> Optional[Self.Message]:
        if event.isa[KeyEvent]():
            return event[KeyEvent].copy()
        return None


def main() raises:
    run(CounterApp())
