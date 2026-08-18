"""Runtime-neutral boundary for scoped command and subscription execution."""

from std.collections import List

from .effects import Command, Subscription, SubscriptionDelta


trait RuntimeAdapter(Deinitable, Movable):
    """A statically typed bridge to a host task runtime.

    Implementations own their task handles and message channel. Mojotui exposes
    no executor, future, or private AsyncRT type in this contract.
    """

    comptime Effect: Deinitable & Movable
    comptime Message: Deinitable & Movable

    def execute(mut self, var command: Command[Self.Effect]) raises:
        """Start one finite effect, preserving optional operation metadata."""
        ...

    def start(mut self, var subscription: Subscription[Self.Effect]) raises:
        """Start one stable-ID ongoing source."""
        ...

    def stop(mut self, id: StringSlice) raises:
        """Cancel and join the ongoing source identified by `id`."""
        ...

    def take_messages(mut self) raises -> List[Self.Message]:
        """Transfer the currently completed typed messages to the host."""
        ...

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

    def execute_commands(mut self, var commands: List[Command[Self.R.Effect]]) raises:
        if self.closed:
            raise Error("runtime scope is closed")
        while len(commands) > 0:
            self.adapter.execute(commands.pop(0))

    def apply_subscription_delta(
        mut self, var delta: SubscriptionDelta[Self.R.Effect]
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

    def take_messages(mut self) raises -> List[Self.R.Message]:
        if self.closed:
            return List[Self.R.Message]()
        return self.adapter.take_messages()

    def close(mut self) raises:
        """Cancel and join owned work exactly once."""
        if self.closed:
            return
        self.adapter.close()
        self.closed = True

    def __deinit__(deinit self):
        if not self.closed:
            self.adapter.close_silently()
