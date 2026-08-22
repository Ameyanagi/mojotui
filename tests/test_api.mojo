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
    MessageClass,
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
    with assert_raises(contains="text alignment must be within [0, 2]; got 3"):
        _ = Alignment(3)
    with assert_raises(contains="layout direction must be within [0, 1]; got -1"):
        _ = Direction(-1)
    with assert_raises(contains="message enqueue result must be within [0, 3]; got 4"):
        _ = EnqueueResult(4)
    with assert_raises(contains="message delivery class must be within [0, 1]; got 2"):
        _ = MessageClass(2)
    with assert_raises(contains="scrollbar orientation must be within [0, 1]; got 2"):
        _ = ScrollbarOrientation(2)
    with assert_raises(contains="editor wrap mode must be within [0, 1]; got 9"):
        _ = WrapMode(9)
    with assert_raises(contains="key code must be within [0, 26]; got 27"):
        _ = KeyCode(27)
    with assert_raises(contains="key modifier flags must be within [0, 7]; got 8"):
        _ = KeyModifiers(8)
    with assert_raises(contains="mouse event kind must be within [0, 4]; got 5"):
        _ = MouseKind(5)
    with assert_raises(contains="mouse button must be within [0, 2]; got -1"):
        _ = MouseButton(-1)
    with assert_raises(contains="editor command kind must be within [0, 17]; got 18"):
        _ = EditorCommandKind(18)
    with assert_raises(
        contains="editor controller action kind must be within [0, 2]; got 3"
    ):
        _ = ControllerActionKind(3)
    with assert_raises(contains="marker affinity must be within [0, 1]; got 2"):
        _ = MarkerAffinity(2)
    with assert_raises(contains="document piece source must be within [0, 1]; got -1"):
        _ = PieceSource(-1)
    with assert_raises(contains="file line ending must be within [0, 1]; got 2"):
        _ = LineEnding(2)
    with assert_raises(contains="terminal color kind must be within [0, 2]; got 3"):
        _ = ColorKind(3)
    with assert_raises(
        contains="terminal modifier flags must be within [0, 255]; got 256"
    ):
        _ = ModifierSet(256)
    with assert_raises(contains="block border flags must be within [0, 15]; got 16"):
        _ = Borders(16)
    with assert_raises(contains="border type must be within [0, 3]; got 4"):
        _ = BorderType(4)
    with assert_raises(contains="block title position must be within [0, 1]; got 2"):
        _ = TitlePosition(2)
    with assert_raises(contains="list highlight spacing must be within [0, 2]; got 3"):
        _ = HighlightSpacing(3)
    with assert_raises(contains="table selection mode must be within [0, 3]; got 4"):
        _ = TableSelection(4)
    with assert_raises(
        contains="application control flow must be within [0, 1]; got 2"
    ):
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
    with assert_raises(
        contains=(
            "requested cursor is outside the completed frame; got cursor (2, 0),"
            " frame=Rect(0, 0, 2, 1)"
        )
    ):
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


def test_present_failure_after_success_forces_physical_resynchronization() raises:
    var terminal = Terminal(FailingBackend(Rect(0, 0, 2, 1)))
    terminal.backend.should_fail = False
    var first = terminal.begin_frame()
    _ = first.buffer.set_cell({0, 0}, Cell("a"))
    var completed = terminal.finish_frame(first^)
    assert_true(completed.full_redraw)

    terminal.backend.should_fail = True
    var failed = terminal.begin_frame()
    _ = failed.buffer.set_cell({1, 0}, Cell("b"))
    with assert_raises(contains="intentional presentation failure"):
        _ = terminal.finish_frame(failed^)
    assert_equal(terminal.frame_count, 1)

    terminal.backend.should_fail = False
    var recovered = terminal.begin_frame()
    _ = recovered.buffer.set_cell({0, 0}, Cell("a"))
    _ = recovered.buffer.set_cell({1, 0}, Cell("b"))
    completed = terminal.finish_frame(recovered^)
    assert_true(completed.full_redraw)


def test_terminal_rejects_a_frame_created_by_another_terminal() raises:
    var first = Terminal(HeadlessBackend(Rect(0, 0, 2, 1)))
    var second = Terminal(HeadlessBackend(Rect(0, 0, 2, 1)))
    var foreign = first.begin_frame()
    with assert_raises(contains="frame belongs to a different terminal"):
        _ = second.finish_frame(foreign^)


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
