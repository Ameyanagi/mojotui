"""Sequential application processing with an injected monotonic clock."""

from std.collections import List, Optional
from std.time import monotonic

from ..terminal.backend import Backend, Terminal
from .contracts import Application, dispatch, render_application, subscriptions
from .effects import (
    Command,
    ControlFlow,
    OperationTracker,
    SubscriptionDelta,
    SubscriptionTracker,
    UpdateResult,
)
from .queue import MessageQueue


trait Clock(Deinitable, Movable):
    """A monotonic nanosecond source supplied by the application host."""

    def now_ns(self) -> Int:
        ...


struct SystemClock(Clock, Copyable):
    """The standard library's system-wide monotonic clock."""

    def __init__(out self):
        pass

    def now_ns(self) -> Int:
        return monotonic()


struct ManualClock(Clock, Copyable):
    """A deterministic clock advanced explicitly by tests or simulations."""

    var current_ns: Int

    def __init__(out self, current_ns: Int = 0):
        self.current_ns = max(current_ns, 0)

    def now_ns(self) -> Int:
        return self.current_ns

    def advance(mut self, nanoseconds: Int):
        var delta = max(nanoseconds, 0)
        if delta > Int.MAX - self.current_ns:
            self.current_ns = Int.MAX
        else:
            self.current_ns += delta

    def set(mut self, nanoseconds: Int):
        """Move forward to a timestamp; requests to move backward are ignored."""
        self.current_ns = max(self.current_ns, nanoseconds)


struct ApplicationRuntime[A: Application, C: Clock](Movable):
    """Own one application, its model, queue, clock, and host-side trackers.

    Effects remain data. `process_one` returns the update result so a concrete
    host adapter can execute its commands and deliver typed messages later.
    """

    var application: Self.A
    var model: Self.A.Model
    var clock: Self.C
    var queue: MessageQueue[Self.A.Message]
    var subscription_tracker: SubscriptionTracker
    var operation_tracker: OperationTracker
    var startup_commands: List[Command[Self.A.Effect]]
    var needs_redraw: Bool
    var exiting: Bool

    def __init__(
        out self,
        var application: Self.A,
        var clock: Self.C,
        queue_capacity: Int = 256,
    ) raises:
        var initialized = application.init()
        self.model = initialized.take_model()
        self.application = application^
        self.clock = clock^
        self.queue = MessageQueue[Self.A.Message](queue_capacity)
        self.subscription_tracker = SubscriptionTracker()
        self.operation_tracker = OperationTracker()
        self.startup_commands = initialized.take_commands()
        self.needs_redraw = True
        self.exiting = False

    def now_ns(self) -> Int:
        return self.clock.now_ns()

    def request_redraw(mut self):
        self.needs_redraw = True

    def take_startup_commands(mut self) -> List[Command[Self.A.Effect]]:
        var commands = self.startup_commands^
        self.startup_commands = List[Command[Self.A.Effect]]()
        return commands^

    def process_one(mut self) raises -> Optional[UpdateResult[Self.A.Effect]]:
        """Process one queued message sequentially, if available."""
        var next = self.queue.dequeue()
        if not next:
            return None
        var result = dispatch(
            self.application,
            self.model,
            next.take(),
        )
        if result.redraw:
            self.needs_redraw = True
        if result.control == ControlFlow.EXIT:
            self.exiting = True
        return result^

    def reconcile_subscriptions(mut self) raises -> SubscriptionDelta[Self.A.Effect]:
        var desired = subscriptions(self.application, self.model)
        return self.subscription_tracker.reconcile(desired^)

    def render_if_needed[
        B: Backend
    ](mut self, mut terminal: Terminal[B]) raises -> Bool:
        """Render and present exactly once when redraw is pending."""
        if not self.needs_redraw:
            return False
        var frame = terminal.begin_frame()
        var area = frame.area()
        render_application(self.application, self.model, area, frame.buffer)
        _ = terminal.finish_frame(frame^)
        self.needs_redraw = False
        return True
