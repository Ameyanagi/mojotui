from std.collections import List
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from mojotui import (
    Application,
    ApplicationRuntime,
    Buffer,
    Cell,
    Command,
    HeadlessBackend,
    ManualClock,
    Rect,
    Subscription,
    Terminal,
    UpdateResult,
)


struct Model(Copyable):
    var count: Int

    def __init__(out self):
        self.count = 0


struct Message(Copyable):
    var delta: Int

    def __init__(out self, delta: Int):
        self.delta = delta


struct Effect(Copyable):
    var observed: Int

    def __init__(out self, observed: Int):
        self.observed = observed


struct RuntimeApplication(Application, Copyable):
    comptime Model = Model
    comptime Message = Message
    comptime Effect = Effect

    def __init__(out self):
        pass

    def init(mut self) raises -> Self.Model:
        return Model()

    def update(
        mut self, mut model: Self.Model, var message: Self.Message
    ) raises -> UpdateResult[Self.Effect]:
        if message.delta == 0:
            return UpdateResult[Self.Effect].unchanged()
        model.count += message.delta
        return UpdateResult(True, [Command(Effect(model.count))])

    def view(self, model: Self.Model, area: Rect, mut buffer: Buffer) raises:
        buffer.fill(area, Cell("+" if model.count > 0 else "0"))

    def subscriptions(
        self, model: Self.Model
    ) raises -> List[Subscription[Self.Effect]]:
        return [Subscription("clock", Effect(model.count), revision=model.count)]


def test_runtime_processes_messages_sequentially_and_returns_effects() raises:
    var runtime = ApplicationRuntime(RuntimeApplication(), ManualClock(), 4)
    _ = runtime.queue.enqueue_lossless(Message(2))
    _ = runtime.queue.enqueue_lossless(Message(3))
    var first = runtime.process_one()
    var second = runtime.process_one()
    assert_true(first)
    assert_true(second)
    assert_equal(first.value().commands[0].effect.observed, 2)
    assert_equal(second.value().commands[0].effect.observed, 5)
    assert_equal(runtime.model.count, 5)
    assert_false(runtime.process_one())


def test_runtime_only_renders_when_requested() raises:
    var runtime = ApplicationRuntime(RuntimeApplication(), ManualClock())
    var terminal = Terminal(HeadlessBackend(Rect(0, 0, 2, 1)))
    assert_true(runtime.render_if_needed(terminal))
    assert_false(runtime.render_if_needed(terminal))
    _ = runtime.queue.enqueue_lossless(Message(1))
    _ = runtime.process_one()
    assert_true(runtime.render_if_needed(terminal))
    assert_equal(terminal.backend.presentation_count, 2)
    assert_equal(terminal.backend.cell({0, 0}).symbol, "+")


def test_runtime_reconciles_subscriptions_after_state_change() raises:
    var runtime = ApplicationRuntime(RuntimeApplication(), ManualClock())
    var initial = runtime.reconcile_subscriptions()
    assert_equal(len(initial.starts), 1)
    assert_equal(len(initial.stops), 0)
    _ = runtime.queue.enqueue_lossless(Message(1))
    _ = runtime.process_one()
    var changed = runtime.reconcile_subscriptions()
    assert_equal(len(changed.starts), 1)
    assert_equal(len(changed.stops), 1)


def test_manual_clock_is_monotonic_and_injected() raises:
    var runtime = ApplicationRuntime(RuntimeApplication(), ManualClock(10))
    assert_equal(runtime.now_ns(), 10)
    runtime.clock.advance(5)
    runtime.clock.set(3)
    assert_equal(runtime.now_ns(), 15)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
