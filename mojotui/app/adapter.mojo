"""Runtime-neutral boundary for scoped command and subscription execution."""

from std.collections import List, Optional

from .contracts import Application
from .effects import Command, Subscription, SubscriptionDelta


trait RuntimeAdapter(Deinitable, Movable):
    """A statically typed bridge to a host task runtime.

    Implementations own their task handles and message channel. Mojotui exposes
    no executor, future, or private AsyncRT type in this contract.
    """

    comptime ApplicationType: Application

    def execute(mut self, var command: Command[Self.ApplicationType.Effect]) raises:
        """Start one finite effect, preserving optional operation metadata."""
        ...

    def start(
        mut self, var subscription: Subscription[Self.ApplicationType.Effect]
    ) raises:
        """Start one stable-ID ongoing source."""
        ...

    def stop(mut self, id: StringSlice) raises:
        """Cancel and join the ongoing source identified by `id`."""
        ...

    def take_messages(mut self) raises -> List[Self.ApplicationType.Message]:
        """Transfer the currently completed typed messages to the host."""
        ...

    def next_deadline_ns(self) -> Optional[Int]:
        """Return an optional monotonic runtime deadline for the host poll."""
        return None

    def on_deadline(mut self, now_ns: Int) raises:
        """Advance runtime-owned timers after their monotonic deadline."""
        pass

    def close(mut self) raises:
        """Cancel and join all work owned by this adapter."""
        ...

    def close_silently(mut self):
        """Best-effort non-raising shutdown used while a scope unwinds."""
        ...


struct RuntimeScope[R: RuntimeAdapter](Movable):
    """Reject new work after shutdown and route all effects through one owner."""

    var adapter: Self.R
    var closed: Bool

    def __init__(out self, var adapter: Self.R):
        self.adapter = adapter^
        self.closed = False

    def execute_commands(
        mut self,
        var commands: List[Command[Self.R.ApplicationType.Effect]],
    ) raises:
        if self.closed:
            raise Error("runtime scope is closed")
        while len(commands) > 0:
            self.adapter.execute(commands.pop(0))

    def apply_subscription_delta(
        mut self,
        var delta: SubscriptionDelta[Self.R.ApplicationType.Effect],
    ) raises:
        if self.closed:
            raise Error("runtime scope is closed")
        # Stop replaced sources before starting their new revisions. This keeps
        # at most one producer alive for each stable ID.
        while len(delta.stops) > 0:
            var id = delta.stops.pop(0)
            self.adapter.stop(id)
        while len(delta.starts) > 0:
            self.adapter.start(delta.starts.pop(0))

    def take_messages(mut self) raises -> List[Self.R.ApplicationType.Message]:
        if self.closed:
            return List[Self.R.ApplicationType.Message]()
        return self.adapter.take_messages()

    def next_deadline_ns(self) -> Optional[Int]:
        if self.closed:
            return None
        return self.adapter.next_deadline_ns()

    def on_deadline(mut self, now_ns: Int) raises:
        if self.closed:
            return
        self.adapter.on_deadline(now_ns)

    def close(mut self) raises:
        """Cancel and join owned work exactly once."""
        if self.closed:
            return
        self.adapter.close()
        self.closed = True

    def __deinit__(deinit self):
        if not self.closed:
            self.adapter.close_silently()
