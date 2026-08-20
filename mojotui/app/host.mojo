"""Lifecycle-safe coordination for typed applications and runtime adapters."""

from std.collections import List, Optional

from ..core.geometry import Size
from ..event.input import InputEvent, InputParser
from ..event.reactor import PosixReactor
from ..terminal.backend import Backend, Terminal
from ..terminal.session import SessionOptions, TerminalSession
from .adapter import RuntimeAdapter, RuntimeScope
from .queue import EnqueueResult
from .runtime import ApplicationRuntime, Clock


def _saturating_add(left: Int, right: Int) -> Int:
    var positive_right = max(right, 0)
    if left > Int.MAX - positive_right:
        return Int.MAX
    return left + positive_right


def _milliseconds_to_nanoseconds(milliseconds: Int) -> Int:
    var positive = max(milliseconds, 0)
    if positive > Int.MAX // 1_000_000:
        return Int.MAX
    return positive * 1_000_000


struct HostSchedule(Copyable):
    """Independent monotonic deadlines used to derive one reactor timeout."""

    var tick_interval_ns: Int
    var escape_timeout_ns: Int
    var frame_interval_ns: Int
    var next_tick_ns: Int
    var last_frame_ns: Int
    var escape_deadline_ns: Optional[Int]
    var frame_deadline_ns: Optional[Int]
    var runtime_deadline_ns: Optional[Int]
    var started: Bool

    def __init__(
        out self,
        tick_interval_ms: Int = 16,
        escape_timeout_ms: Int = 25,
        frame_interval_ms: Int = 16,
    ):
        self.tick_interval_ns = max(
            _milliseconds_to_nanoseconds(tick_interval_ms), 1_000_000
        )
        self.escape_timeout_ns = max(
            _milliseconds_to_nanoseconds(escape_timeout_ms), 1_000_000
        )
        self.frame_interval_ns = max(
            _milliseconds_to_nanoseconds(frame_interval_ms), 1_000_000
        )
        self.next_tick_ns = 0
        self.last_frame_ns = 0
        self.escape_deadline_ns = None
        self.frame_deadline_ns = None
        self.runtime_deadline_ns = None
        self.started = False

    def start(mut self, now_ns: Int):
        if self.started:
            return
        var now = max(now_ns, 0)
        self.next_tick_ns = _saturating_add(now, self.tick_interval_ns)
        self.last_frame_ns = now
        self.started = True

    def arm_escape(mut self, now_ns: Int):
        if not self.escape_deadline_ns:
            self.escape_deadline_ns = _saturating_add(
                max(now_ns, 0), self.escape_timeout_ns
            )

    def clear_escape(mut self):
        self.escape_deadline_ns = None

    def request_frame(mut self, now_ns: Int):
        if self.frame_deadline_ns:
            return
        var earliest = _saturating_add(self.last_frame_ns, self.frame_interval_ns)
        self.frame_deadline_ns = max(max(now_ns, 0), earliest)

    def mark_frame(mut self, now_ns: Int):
        self.last_frame_ns = max(now_ns, 0)
        self.frame_deadline_ns = None

    def set_runtime_deadline(mut self, deadline_ns: Optional[Int]):
        if deadline_ns:
            self.runtime_deadline_ns = max(deadline_ns.value(), 0)
        else:
            self.runtime_deadline_ns = None

    def tick_due(self, now_ns: Int) -> Bool:
        return self.started and now_ns >= self.next_tick_ns

    def consume_tick(mut self, now_ns: Int) -> Bool:
        if not self.tick_due(now_ns):
            return False
        self.next_tick_ns = _saturating_add(max(now_ns, 0), self.tick_interval_ns)
        return True

    def escape_due(self, now_ns: Int) -> Bool:
        if self.escape_deadline_ns:
            return now_ns >= self.escape_deadline_ns.value()
        return False

    def frame_due(self, now_ns: Int) -> Bool:
        if self.frame_deadline_ns:
            return now_ns >= self.frame_deadline_ns.value()
        return False

    def runtime_due(self, now_ns: Int) -> Bool:
        if self.runtime_deadline_ns:
            return now_ns >= self.runtime_deadline_ns.value()
        return False

    def _nearest_deadline(self) -> Int:
        var nearest = self.next_tick_ns
        if self.escape_deadline_ns:
            nearest = min(nearest, self.escape_deadline_ns.value())
        if self.frame_deadline_ns:
            nearest = min(nearest, self.frame_deadline_ns.value())
        if self.runtime_deadline_ns:
            nearest = min(nearest, self.runtime_deadline_ns.value())
        return nearest

    def poll_timeout_ms(
        self,
        now_ns: Int,
        maximum_wait_ms: Int,
        immediate_work: Bool = False,
    ) -> Int:
        if immediate_work:
            return 0
        var remaining = self._nearest_deadline() - max(now_ns, 0)
        if remaining <= 0:
            return 0
        var milliseconds = remaining // 1_000_000
        if remaining % 1_000_000 != 0:
            milliseconds += 1
        return min(milliseconds, max(maximum_wait_ms, 0))


struct HostStep(Copyable):
    """Observable work completed by one non-blocking host turn."""

    var messages_processed: Int
    var rendered: Bool
    var exiting: Bool

    def __init__(
        out self,
        messages_processed: Int = 0,
        rendered: Bool = False,
        exiting: Bool = False,
    ):
        self.messages_processed = max(messages_processed, 0)
        self.rendered = rendered
        self.exiting = exiting


struct ApplicationHost[
    R: RuntimeAdapter,
    C: Clock,
    B: Backend,
](Movable):
    """Own application state, runtime scope, and terminal presentation.

    The host coordinates finite turns only. `RuntimeAdapter` remains the sole
    owner and executor of background tasks.
    """

    var runtime: ApplicationRuntime[Self.R.ApplicationType, Self.C]
    var scope: RuntimeScope[Self.R]
    var terminal: Terminal[Self.B]
    var pending_adapter_messages: List[Self.R.ApplicationType.Message]
    var max_messages_per_step: Int
    var started: Bool
    var closed: Bool

    def __init__(
        out self,
        var adapter: Self.R,
        var application: Self.R.ApplicationType,
        var clock: Self.C,
        var backend: Self.B,
        queue_capacity: Int = 256,
        max_messages_per_step: Int = 64,
    ) raises:
        self.runtime = ApplicationRuntime(
            application^,
            clock^,
            queue_capacity,
        )
        self.scope = RuntimeScope(adapter^)
        self.terminal = Terminal(backend^)
        self.pending_adapter_messages = List[Self.R.ApplicationType.Message]()
        self.max_messages_per_step = max(max_messages_per_step, 1)
        self.started = False
        self.closed = False

    def start(mut self) raises:
        """Execute startup commands and establish initial subscriptions once."""
        if self.closed:
            raise Error("application host is closed")
        if self.started:
            return
        self.scope.execute_commands(self.runtime.take_startup_commands())
        self.scope.apply_subscription_delta(self.runtime.reconcile_subscriptions())
        self.started = True

    def enqueue(mut self, var message: Self.R.ApplicationType.Message) raises:
        if self.closed:
            raise Error("application host is closed")
        var result = self.runtime.queue.enqueue_lossless(message^)
        if result == EnqueueResult.BACKPRESSURE:
            raise Error("application message queue is full")

    def enqueue_latest(
        mut self,
        var key: String,
        var message: Self.R.ApplicationType.Message,
    ) -> EnqueueResult:
        if self.closed:
            return EnqueueResult.DROPPED_COALESCIBLE
        return self.runtime.queue.enqueue_latest(key^, message^)

    def can_enqueue_lossless(self) -> Bool:
        return not self.closed and self.runtime.queue.can_accept_lossless()

    def has_immediate_work(self) -> Bool:
        return len(self.runtime.queue) > 0 or len(self.pending_adapter_messages) > 0

    def handle_input(mut self, var event: InputEvent) raises:
        """Map one terminal event through the application and enqueue it."""
        var message = self.runtime.application.on_input(
            self.runtime.model,
            event^,
        )
        if message:
            self.enqueue(message.take())

    def handle_tick(mut self) raises:
        """Map the injected monotonic time through the application."""
        var message = self.runtime.application.on_tick(
            self.runtime.model,
            self.runtime.now_ns(),
        )
        if message:
            _ = self.enqueue_latest(String("host.tick"), message.take())

    def handle_resize(mut self, size: Size) raises:
        """Invalidate presentation and optionally enqueue a resize message."""
        self.terminal.handle_resize(size)
        self.runtime.request_redraw()
        var message = self.runtime.application.on_resize(
            self.runtime.model,
            size,
        )
        if message:
            _ = self.enqueue_latest(String("host.resize"), message.take())

    def _collect_adapter_messages(mut self) raises:
        if len(self.pending_adapter_messages) == 0:
            self.pending_adapter_messages = self.scope.take_messages()
        while (
            len(self.pending_adapter_messages) > 0
            and self.runtime.queue.can_accept_lossless()
        ):
            var result = self.runtime.queue.enqueue_lossless(
                self.pending_adapter_messages.pop(0)
            )
            if result == EnqueueResult.BACKPRESSURE:
                raise Error("message queue capacity changed during adapter transfer")

    def pending_adapter_message_count(self) -> Int:
        """Return completions retained by the host until queue capacity exists."""
        return len(self.pending_adapter_messages)

    def render_if_needed(mut self) raises -> Bool:
        return self.runtime.render_if_needed(self.terminal)

    def step(mut self, render: Bool = True) raises -> HostStep:
        """Transfer completions, process queued messages, and render if needed."""
        self.start()
        self._collect_adapter_messages()
        var processed = 0
        while processed < self.max_messages_per_step:
            var update = self.runtime.process_one()
            if not update:
                break
            var result = update.take()
            self.scope.execute_commands(result.take_commands())
            processed += 1
            if self.runtime.exiting:
                break
        if processed > 0:
            self.scope.apply_subscription_delta(self.runtime.reconcile_subscriptions())
        var rendered = self.render_if_needed() if render else False
        return HostStep(processed, rendered, self.runtime.exiting)

    def close(mut self) raises:
        """Cancel and join runtime work; repeated calls are harmless."""
        if self.closed:
            return
        self.scope.close()
        self.closed = True

    def __deinit__(deinit self):
        # RuntimeScope performs best-effort adapter shutdown if explicit close
        # was skipped. Terminal backends have no independent task ownership.
        pass


struct TerminalApplicationHost[
    R: RuntimeAdapter,
    C: Clock,
    B: Backend,
](Movable):
    """Own POSIX terminal lifecycle and coordinate one typed application.

    `SessionOptions.alternate_screen` selects fullscreen or inline-compatible
    session behavior. Background execution stays inside `RuntimeAdapter`.
    """

    var session: TerminalSession
    var application: ApplicationHost[Self.R, Self.C, Self.B]
    var reactor: PosixReactor
    var parser: InputParser
    var pending_input_events: List[InputEvent]
    var schedule: HostSchedule
    var maximum_poll_ms: Int
    var closed: Bool

    def __init__(
        out self,
        var adapter: Self.R,
        var application: Self.R.ApplicationType,
        var clock: Self.C,
        var backend: Self.B,
        options: SessionOptions = SessionOptions(),
        input_descriptor: Int = 0,
        output_descriptor: Int = 1,
        wakeup_descriptor: Int = -1,
        tick_interval_ms: Int = 16,
        escape_timeout_ms: Int = 25,
        frame_interval_ms: Int = 16,
        maximum_poll_ms: Int = 1_000,
        queue_capacity: Int = 256,
        max_messages_per_step: Int = 64,
    ) raises:
        self.session = TerminalSession(
            input_descriptor,
            output_descriptor,
            options,
        )
        self.application = ApplicationHost(
            adapter^,
            application^,
            clock^,
            backend^,
            queue_capacity,
            max_messages_per_step,
        )
        self.reactor = PosixReactor(
            input_descriptor,
            output_descriptor,
            wakeup_descriptor,
        )
        self.parser = InputParser()
        self.pending_input_events = List[InputEvent]()
        self.schedule = HostSchedule(
            tick_interval_ms,
            escape_timeout_ms,
            frame_interval_ms,
        )
        self.maximum_poll_ms = max(maximum_poll_ms, 0)
        self.closed = False

    def _handle_events(mut self, var events: List[InputEvent]) raises:
        self.pending_input_events.extend(events^)
        self._drain_input_events()

    def _drain_input_events(mut self) raises:
        while (
            len(self.pending_input_events) > 0
            and self.application.can_enqueue_lossless()
        ):
            self.application.handle_input(self.pending_input_events.pop(0))

    def _refresh_escape_deadline(mut self, now_ns: Int):
        if self.parser.pending_byte_count() > 0:
            self.schedule.arm_escape(now_ns)
        else:
            self.schedule.clear_escape()

    def _has_immediate_work(self) -> Bool:
        return self.application.has_immediate_work() or (
            len(self.pending_input_events) > 0
            and self.application.can_enqueue_lossless()
        )

    def _run_application_turn(mut self, now_ns: Int) raises -> HostStep:
        self._drain_input_events()
        var step = self.application.step(render=False)
        if self.application.runtime.needs_redraw:
            self.schedule.request_frame(now_ns)
        var rendered = False
        if self.schedule.frame_due(now_ns) or step.exiting:
            rendered = self.application.render_if_needed()
            if rendered:
                self.schedule.mark_frame(now_ns)
        return HostStep(step.messages_processed, rendered, step.exiting)

    def poll_once(mut self) raises -> HostStep:
        """Wait once, translate host observations, then run one finite turn."""
        if self.closed:
            raise Error("terminal application host is closed")
        var before_wait = self.application.runtime.now_ns()
        self.schedule.start(before_wait)
        self.schedule.set_runtime_deadline(self.application.scope.next_deadline_ns())
        self._drain_input_events()
        var can_read_input = (
            len(self.pending_input_events) == 0
            and self.application.can_enqueue_lossless()
        )
        var timeout_ms = self.schedule.poll_timeout_ms(
            before_wait,
            self.maximum_poll_ms,
            self._has_immediate_work(),
        )
        var observation = self.reactor.wait(timeout_ms)
        if observation.failed:
            raise Error("terminal reactor failed")
        var now_ns = self.application.runtime.now_ns()
        if observation.input_ready and can_read_input:
            self._handle_events(self.reactor.read_events(self.parser))
            self._refresh_escape_deadline(now_ns)
        if self.schedule.escape_due(now_ns):
            self._handle_events(self.parser.flush_escape())
            self.schedule.clear_escape()
            self._refresh_escape_deadline(now_ns)
        if self.schedule.consume_tick(now_ns):
            self.application.handle_tick()
        if observation.resized:
            self.application.handle_resize(observation.size)
        if observation.wakeup_ready:
            _ = self.reactor.read_wakeup()
        if self.schedule.runtime_due(now_ns):
            self.application.scope.on_deadline(now_ns)
            self.schedule.set_runtime_deadline(
                self.application.scope.next_deadline_ns()
            )
        if observation.hangup:
            self.application.runtime.exiting = True
        return self._run_application_turn(now_ns)

    def run(mut self) raises:
        """Render initially and coordinate turns until exit or terminal hangup."""
        try:
            var now_ns = self.application.runtime.now_ns()
            self.schedule.start(now_ns)
            var step = self.application.step(render=False)
            var rendered = self.application.render_if_needed()
            if rendered:
                self.schedule.mark_frame(now_ns)
            while not step.exiting:
                step = self.poll_once()
        finally:
            self.close()

    def close(mut self) raises:
        """Stop owned work, flush output, and restore the terminal exactly once."""
        if self.closed:
            return
        try:
            self.application.close()
        finally:
            try:
                self.application.terminal.flush()
            finally:
                try:
                    self.session.close()
                finally:
                    self.closed = True

    def __deinit__(deinit self):
        # Owned members provide non-raising fallback cleanup during unwinding.
        pass
