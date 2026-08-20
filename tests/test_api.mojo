from std.collections import List
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)

from mojotui import (
    Alignment,
    Application,
    Backend,
    BorderType,
    Borders,
    Buffer,
    Cell,
    ColorKind,
    Command,
    ControlFlow,
    ControllerActionKind,
    Direction,
    EditorCommandKind,
    EnqueueResult,
    FramePatch,
    HeadlessBackend,
    HighlightSpacing,
    KeyCode,
    KeyModifiers,
    InitResult,
    LineEnding,
    MarkerAffinity,
    ModifierSet,
    MouseButton,
    MouseKind,
    PieceSource,
    Rect,
    ScrollbarOrientation,
    Subscription,
    Terminal,
    TableSelection,
    TitlePosition,
    UpdateResult,
    Widget,
    WrapMode,
    dispatch,
    render_application,
)


struct FillWidget(Copyable, Widget):
    var cell: Cell

    def __init__(out self, cell: Cell):
        self.cell = cell.copy()

    def render(self, area: Rect, mut buffer: Buffer):
        buffer.fill(area, self.cell)


struct FailingBackend(Backend, Movable):
    var area: Rect
    var should_fail: Bool
    var presentation_count: Int

    def __init__(out self, area: Rect):
        self.area = area.copy()
        self.should_fail = True
        self.presentation_count = 0

    def viewport(mut self) raises -> Rect:
        return self.area.copy()

    def present(mut self, patch: FramePatch) raises:
        _ = patch
        if self.should_fail:
            raise Error("intentional presentation failure")
        self.presentation_count += 1

    def clear(mut self) raises:
        pass

    def flush(mut self) raises:
        pass


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

    def init(mut self) raises -> InitResult[Self.Model, Self.Effect]:
        return InitResult[Self.Model, Self.Effect].ready(CounterModel())

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


def test_nominal_public_values_reject_invalid_discriminants() raises:
    with assert_raises(contains="invalid text alignment"):
        _ = Alignment(3)
    with assert_raises(contains="invalid layout direction"):
        _ = Direction(-1)
    with assert_raises(contains="invalid message enqueue result"):
        _ = EnqueueResult(4)
    with assert_raises(contains="invalid scrollbar orientation"):
        _ = ScrollbarOrientation(2)
    with assert_raises(contains="invalid editor wrap mode"):
        _ = WrapMode(9)
    with assert_raises(contains="invalid key code"):
        _ = KeyCode(15)
    with assert_raises(contains="invalid key modifier flags"):
        _ = KeyModifiers(8)
    with assert_raises(contains="invalid mouse event kind"):
        _ = MouseKind(5)
    with assert_raises(contains="invalid mouse button"):
        _ = MouseButton(-1)
    with assert_raises(contains="invalid editor command kind"):
        _ = EditorCommandKind(18)
    with assert_raises(contains="invalid editor controller action kind"):
        _ = ControllerActionKind(3)
    with assert_raises(contains="invalid marker affinity"):
        _ = MarkerAffinity(2)
    with assert_raises(contains="invalid document piece source"):
        _ = PieceSource(-1)
    with assert_raises(contains="invalid file line ending"):
        _ = LineEnding(2)
    with assert_raises(contains="invalid terminal color kind"):
        _ = ColorKind(3)
    with assert_raises(contains="invalid terminal modifier flags"):
        _ = ModifierSet(256)
    with assert_raises(contains="invalid block border flags"):
        _ = Borders(16)
    with assert_raises(contains="invalid border type"):
        _ = BorderType(4)
    with assert_raises(contains="invalid block title position"):
        _ = TitlePosition(2)
    with assert_raises(contains="invalid list highlight spacing"):
        _ = HighlightSpacing(3)
    with assert_raises(contains="invalid table selection mode"):
        _ = TableSelection(4)
    with assert_raises(contains="invalid application control flow"):
        _ = ControlFlow(2)


def test_terminal_uses_concrete_headless_backend() raises:
    var terminal = Terminal(HeadlessBackend(Rect(0, 0, 2, 1)))
    var frame = terminal.begin_frame()
    _ = frame.buffer.set_cell({1, 0}, Cell("m"))
    var completed = terminal.finish_frame(frame^)
    assert_true(completed.full_redraw)
    assert_equal(completed.frame_count, 1)
    assert_equal(completed.changed_cell_count, 1)
    assert_equal(terminal.backend.presentation_count, 1)
    assert_equal(terminal.backend.cell({1, 0}).symbol, "m")


def test_frame_dispatches_widgets_and_immediate_mode_clears_old_cells() raises:
    var terminal = Terminal(HeadlessBackend(Rect(0, 0, 3, 1)))
    var first = terminal.begin_frame()
    first.render_widget(FillWidget(Cell("x")), Rect(0, 0, 2, 1))
    var completed = terminal.finish_frame(first^)
    assert_equal(completed.changed_cell_count, 2)

    var second = terminal.begin_frame()
    second.render_widget(FillWidget(Cell("x")), Rect(0, 0, 1, 1))
    completed = terminal.finish_frame(second^)
    assert_false(completed.full_redraw)
    assert_equal(completed.changed_cell_count, 1)
    assert_equal(terminal.backend.cell({0, 0}).symbol, "x")
    assert_equal(terminal.backend.cell({1, 0}).symbol, " ")


def test_terminal_rejects_stale_frames_and_out_of_bounds_cursor() raises:
    var terminal = Terminal(HeadlessBackend(Rect(0, 0, 2, 1)))
    var first = terminal.begin_frame()
    var stale = terminal.begin_frame()
    first.set_cursor_position({1, 0})
    _ = terminal.finish_frame(first^)
    assert_true(terminal.backend.cursor)
    assert_true(terminal.backend.cursor.value().equals({1, 0}))
    with assert_raises(contains="stale terminal generation"):
        _ = terminal.finish_frame(stale^)

    var invalid = terminal.begin_frame()
    invalid.set_cursor_position({2, 0})
    with assert_raises(contains="cursor is outside"):
        _ = terminal.finish_frame(invalid^)


def test_terminal_autoresizes_before_preparing_a_frame() raises:
    var terminal = Terminal(HeadlessBackend(Rect(0, 0, 2, 1)))
    var first = terminal.begin_frame()
    _ = terminal.finish_frame(first^)
    terminal.backend.resize(Rect(0, 0, 4, 2))
    var resized = terminal.begin_frame()
    assert_true(resized.area().equals(Rect(0, 0, 4, 2)))
    var completed = terminal.finish_frame(resized^)
    assert_true(completed.full_redraw)


def test_terminal_invalidation_repaints_unchanged_content() raises:
    var terminal = Terminal(HeadlessBackend(Rect(0, 0, 2, 1)))
    var first = terminal.begin_frame()
    _ = first.buffer.set_cell({0, 0}, Cell("x"))
    _ = terminal.finish_frame(first^)

    terminal.invalidate()
    var repainted = terminal.begin_frame()
    _ = repainted.buffer.set_cell({0, 0}, Cell("x"))
    var completed = terminal.finish_frame(repainted^)
    assert_true(completed.full_redraw)
    assert_equal(completed.changed_cell_count, 1)
    assert_equal(terminal.backend.cell({0, 0}).symbol, "x")


def test_terminal_clear_resets_backend_and_frame_history() raises:
    var terminal = Terminal(HeadlessBackend(Rect(0, 0, 2, 1)))
    var first = terminal.begin_frame()
    _ = first.buffer.set_cell({0, 0}, Cell("x"))
    _ = terminal.finish_frame(first^)
    terminal.clear()
    terminal.flush()
    assert_equal(terminal.last_frame().cell({0, 0}).symbol, " ")
    assert_equal(terminal.backend.cell({0, 0}).symbol, " ")

    var redrawn = terminal.begin_frame()
    _ = redrawn.buffer.set_cell({0, 0}, Cell("x"))
    var completed = terminal.finish_frame(redrawn^)
    assert_false(completed.full_redraw)
    assert_equal(completed.changed_cell_count, 1)


def test_terminal_only_commits_a_successfully_presented_frame() raises:
    var terminal = Terminal(FailingBackend(Rect(0, 0, 2, 1)))
    var failed = terminal.begin_frame()
    _ = failed.buffer.set_cell({0, 0}, Cell("x"))
    with assert_raises(contains="intentional presentation failure"):
        _ = terminal.finish_frame(failed^)
    assert_equal(terminal.frame_count, 0)
    assert_equal(terminal.last_frame().cell({0, 0}).symbol, " ")

    terminal.backend.should_fail = False
    var recovered = terminal.begin_frame()
    _ = recovered.buffer.set_cell({1, 0}, Cell("y"))
    var completed = terminal.finish_frame(recovered^)
    assert_true(completed.full_redraw)
    assert_equal(completed.frame_count, 1)
    assert_equal(terminal.last_frame().cell({1, 0}).symbol, "y")


def test_application_uses_typed_model_and_message_contract() raises:
    var application = CounterApplication()
    var initialized = application.init()
    var model = initialized.take_model()
    var startup_commands = initialized.take_commands()
    assert_equal(len(startup_commands), 0)
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
