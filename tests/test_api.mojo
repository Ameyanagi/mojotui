from std.collections import List
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from mojotui import (
    Application,
    Buffer,
    Cell,
    Command,
    HeadlessBackend,
    Rect,
    Subscription,
    Terminal,
    UpdateResult,
    Widget,
    dispatch,
    render_application,
)


struct FillWidget(Copyable, Widget):
    var cell: Cell

    def __init__(out self, cell: Cell):
        self.cell = cell.copy()

    def render(self, area: Rect, mut buffer: Buffer):
        buffer.fill(area, self.cell)


struct CounterModel(Copyable):
    var value: Int

    def __init__(out self, value: Int = 0):
        self.value = value


struct CounterMessage(Copyable):
    var delta: Int

    def __init__(out self, delta: Int):
        self.delta = delta


struct CounterEffect(Copyable):
    var delta: Int

    def __init__(out self, delta: Int):
        self.delta = delta


struct CounterApplication(Application, Copyable):
    comptime Model = CounterModel
    comptime Message = CounterMessage
    comptime Effect = CounterEffect

    def __init__(out self):
        pass

    def init(mut self) raises -> Self.Model:
        return CounterModel()

    def update(
        mut self, mut model: Self.Model, var message: Self.Message
    ) raises -> UpdateResult[Self.Effect]:
        if message.delta == 0:
            return UpdateResult[Self.Effect].unchanged()
        model.value += message.delta
        return UpdateResult[Self.Effect](
            commands=[Command(CounterEffect(message.delta))]
        )

    def view(self, model: Self.Model, area: Rect, mut buffer: Buffer) raises:
        if model.value > 0:
            buffer.fill(area, Cell("+"))

    def subscriptions(
        self, model: Self.Model
    ) raises -> List[Subscription[Self.Effect]]:
        if model.value > 0:
            return [Subscription("positive", CounterEffect(model.value))]
        return []


def test_widget_renders_through_static_contract() raises:
    var buffer = Buffer(Rect(0, 0, 3, 2))
    var widget = FillWidget(Cell("x"))
    widget.render(Rect(1, 0, 2, 1), buffer)
    assert_equal(buffer.cell({1, 0}).symbol, "x")
    assert_equal(buffer.cell({0, 0}).symbol, " ")


def test_terminal_uses_concrete_headless_backend() raises:
    var terminal = Terminal(HeadlessBackend(Rect(0, 0, 2, 1)))
    var frame = Buffer(terminal.viewport())
    _ = frame.set_cell({1, 0}, Cell("m"))
    terminal.present(frame)
    assert_equal(terminal.backend.presentation_count, 1)
    assert_equal(terminal.backend.cell({1, 0}).symbol, "m")


def test_application_uses_typed_model_and_message_contract() raises:
    var application = CounterApplication()
    var model = application.init()
    var unchanged = dispatch(application, model, CounterMessage(0))
    assert_false(unchanged.redraw)
    var changed = dispatch(application, model, CounterMessage(2))
    assert_true(changed.redraw)
    assert_equal(len(changed.commands), 1)
    assert_equal(changed.commands[0].effect.delta, 2)
    assert_equal(model.value, 2)

    var buffer = Buffer(Rect(0, 0, 2, 1))
    var area = buffer.area.copy()
    render_application(application, model, area, buffer)
    assert_equal(buffer.cell({0, 0}).symbol, "+")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
