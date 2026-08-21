from std.collections import List, Optional
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from mojotui import (
    Application,
    ApplicationHost,
    Buffer,
    Cell,
    Command,
    HeadlessBackend,
    HostSchedule,
    InitResult,
    InputEvent,
    KeyEvent,
    ManualClock,
    NoopAdapter,
    Rect,
    RuntimeAdapter,
    Size,
    Subscription,
    SystemClock,
    UpdateResult,
)


struct HostModel(Copyable):
    var value: Int

    def __init__(out self, value: Int = 0):
        self.value = value


struct HostMessage(Copyable):
    var value: Int

    def __init__(out self, value: Int):
        self.value = value


struct HostEffect(Copyable):
    var value: Int

    def __init__(out self, value: Int):
        self.value = value


struct HostApplication(Application, Copyable):
    comptime Model = HostModel
    comptime Message = HostMessage
    comptime Effect = HostEffect

    def __init__(out self):
        pass

    def init(mut self) raises -> InitResult[Self.Model, Self.Effect]:
        return InitResult(HostModel(), [Command(HostEffect(1))])

    def update(
        mut self, mut model: Self.Model, var message: Self.Message
    ) raises -> UpdateResult[Self.Effect]:
        model.value = message.value
        if message.value == 2:
            return UpdateResult[Self.Effect].exit(redraw=True)
        if message.value >= 10:
            return UpdateResult[Self.Effect](redraw=True)
        return UpdateResult(True, [Command(HostEffect(message.value + 1))])

    def view(self, model: Self.Model, area: Rect, mut buffer: Buffer) raises:
        buffer.fill(area, Cell("+" if model.value > 0 else "0"))

    def on_input(
        self, model: Self.Model, var event: InputEvent
    ) raises -> Optional[Self.Message]:
        if event.isa[KeyEvent]():
            var key = event[KeyEvent].copy()
            if key.code == KeyEvent.CHARACTER and key.text == "x":
                return HostMessage(3)
        return None

    def on_tick(self, model: Self.Model, now_ns: Int) raises -> Optional[Self.Message]:
        return HostMessage(now_ns)

    def on_resize(self, model: Self.Model, size: Size) raises -> Optional[Self.Message]:
        return HostMessage(size.width)


struct NoopTestApplication(Application, Copyable):
    comptime Model = HostModel
    comptime Message = KeyEvent
    comptime Effect = Bool

    def __init__(out self):
        pass

    def init(mut self) raises -> InitResult[Self.Model, Self.Effect]:
        return InitResult[Self.Model, Self.Effect].ready(HostModel())

    def update(
        mut self, mut model: Self.Model, var message: Self.Message
    ) raises -> UpdateResult[Self.Effect]:
        model.value += 1
        return UpdateResult[Self.Effect].redraw_only()

    def view(self, model: Self.Model, area: Rect, mut buffer: Buffer) raises:
        buffer.fill(area, Cell("+" if model.value > 0 else "0"))


struct HostAdapter(RuntimeAdapter):
    comptime ApplicationType = HostApplication

    var executed: List[Int]
    var pending: List[HostMessage]
    var close_count: Int

    def __init__(out self):
        self.executed = List[Int]()
        self.pending = List[HostMessage]()
        self.close_count = 0

    def execute(mut self, var command: Command[Self.ApplicationType.Effect]) raises:
        self.executed.append(command.effect.value)
        self.pending.append(HostMessage(command.effect.value))

    def start(
        mut self, var subscription: Subscription[Self.ApplicationType.Effect]
    ) raises:
        pass

    def stop(mut self, id: StringSlice) raises:
        pass

    def take_messages(mut self) raises -> List[Self.ApplicationType.Message]:
        var result = self.pending^
        self.pending = List[HostMessage]()
        return result^

    def close(mut self) raises:
        self.close_count += 1

    def close_silently(mut self):
        self.close_count += 1


def test_noop_adapter_drives_headless_application_host() raises:
    var host = ApplicationHost(
        NoopAdapter[NoopTestApplication](),
        NoopTestApplication(),
        SystemClock(),
        HeadlessBackend(Rect(0, 0, 1, 1)),
    )
    host.enqueue(KeyEvent(KeyEvent.ENTER))
    var step = host.step()
    assert_equal(step.messages_processed, 1)
    assert_true(step.rendered)
    assert_equal(host.runtime.model.value, 1)
    host.close()


def test_host_runs_startup_update_render_and_exit_turns() raises:
    var host = ApplicationHost(
        HostAdapter(),
        HostApplication(),
        ManualClock(),
        HeadlessBackend(Rect(0, 0, 2, 1)),
    )
    var first = host.step()
    assert_equal(first.messages_processed, 1)
    assert_true(first.rendered)
    assert_false(first.exiting)
    assert_equal(host.scope.adapter.executed, [1, 2])
    assert_equal(host.runtime.model.value, 1)
    assert_equal(host.terminal.backend.cell({0, 0}).symbol, "+")

    var second = host.step()
    assert_equal(second.messages_processed, 1)
    assert_true(second.rendered)
    assert_true(second.exiting)
    assert_equal(host.runtime.model.value, 2)


def test_host_starts_and_closes_owned_runtime_once() raises:
    var host = ApplicationHost(
        HostAdapter(),
        HostApplication(),
        ManualClock(),
        HeadlessBackend(Rect(0, 0, 1, 1)),
    )
    host.start()
    host.start()
    assert_equal(host.scope.adapter.executed, [1])
    host.close()
    host.close()
    assert_true(host.closed)
    assert_equal(host.scope.adapter.close_count, 1)
    try:
        host.start()
    except:
        return
    raise Error("closed application host must reject restart")


def test_host_maps_input_tick_and_resize_to_typed_messages() raises:
    var host = ApplicationHost(
        HostAdapter(),
        HostApplication(),
        ManualClock(7),
        HeadlessBackend(Rect(0, 0, 1, 1)),
    )
    host.handle_input(InputEvent(KeyEvent.character("x")))
    host.handle_tick()
    host.handle_resize(Size(9, 4))
    assert_equal(len(host.runtime.queue), 3)
    var input_message = host.runtime.queue.dequeue()
    var tick_message = host.runtime.queue.dequeue()
    var resize_message = host.runtime.queue.dequeue()
    assert_equal(input_message.value().value, 3)
    assert_equal(tick_message.value().value, 7)
    assert_equal(resize_message.value().value, 9)


def test_host_retains_adapter_batch_while_lossless_queue_is_full() raises:
    var host = ApplicationHost(
        HostAdapter(),
        HostApplication(),
        ManualClock(),
        HeadlessBackend(Rect(0, 0, 1, 1)),
        queue_capacity=1,
    )
    host.start()
    host.scope.adapter.pending = [HostMessage(10), HostMessage(11), HostMessage(12)]

    var first = host.step()
    assert_equal(first.messages_processed, 1)
    assert_equal(host.runtime.model.value, 10)
    assert_equal(host.pending_adapter_message_count(), 2)

    var second = host.step()
    assert_equal(second.messages_processed, 1)
    assert_equal(host.runtime.model.value, 11)
    assert_equal(host.pending_adapter_message_count(), 1)

    var third = host.step()
    assert_equal(third.messages_processed, 1)
    assert_equal(host.runtime.model.value, 12)
    assert_equal(host.pending_adapter_message_count(), 0)


def test_host_bounds_each_message_batch_and_still_renders() raises:
    var host = ApplicationHost(
        HostAdapter(),
        HostApplication(),
        ManualClock(),
        HeadlessBackend(Rect(0, 0, 1, 1)),
        queue_capacity=8,
        max_messages_per_step=2,
    )
    host.start()
    host.scope.adapter.pending.clear()
    host.enqueue(HostMessage(10))
    host.enqueue(HostMessage(11))
    host.enqueue(HostMessage(12))

    var first = host.step()
    assert_equal(first.messages_processed, 2)
    assert_true(first.rendered)
    assert_equal(host.runtime.model.value, 11)
    assert_equal(len(host.runtime.queue), 1)

    var second = host.step()
    assert_equal(second.messages_processed, 1)
    assert_true(second.rendered)
    assert_equal(host.runtime.model.value, 12)


def test_host_schedule_uses_independent_nearest_deadlines() raises:
    var schedule = HostSchedule(
        tick_interval_ms=100,
        escape_timeout_ms=25,
        frame_interval_ms=16,
    )
    schedule.start(0)
    assert_equal(schedule.poll_timeout_ms(0, 1_000), 100)

    schedule.request_frame(0)
    schedule.arm_escape(0)
    schedule.set_runtime_deadline(20_000_000)
    assert_equal(schedule.poll_timeout_ms(0, 1_000), 16)
    assert_true(schedule.frame_due(16_000_000))

    schedule.mark_frame(16_000_000)
    assert_equal(schedule.poll_timeout_ms(16_000_000, 1_000), 4)
    assert_true(schedule.runtime_due(20_000_000))
    assert_true(schedule.escape_due(25_000_000))
    assert_false(schedule.tick_due(99_000_000))
    assert_true(schedule.consume_tick(100_000_000))
    assert_false(schedule.tick_due(100_000_000))
    assert_equal(schedule.poll_timeout_ms(100_000_000, 1_000, True), 0)


def test_tick_and_resize_messages_coalesce_to_latest_values() raises:
    var host = ApplicationHost(
        HostAdapter(),
        HostApplication(),
        ManualClock(7),
        HeadlessBackend(Rect(0, 0, 1, 1)),
    )
    host.handle_tick()
    host.runtime.clock.set(8)
    host.handle_tick()
    host.handle_resize(Size(9, 4))
    host.handle_resize(Size(10, 4))

    assert_equal(len(host.runtime.queue), 2)
    var tick_message = host.runtime.queue.dequeue()
    var resize_message = host.runtime.queue.dequeue()
    assert_equal(tick_message.value().value, 8)
    assert_equal(resize_message.value().value, 10)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
