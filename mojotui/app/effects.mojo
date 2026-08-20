"""Runtime-neutral effect, operation, and subscription descriptors."""

from std.collections import List, Optional


struct ControlFlow(Copyable, Equatable, ImplicitlyCopyable):
    """Nominal application-loop continuation decision."""

    comptime CONTINUE = ControlFlow(0, _validated=True)
    comptime EXIT = ControlFlow(1, _validated=True)

    var _value: Int

    def __init__(out self, value: Int, *, _validated: Bool):
        self._value = value

    def __init__(out self, value: Int) raises:
        if value < 0 or value > 1:
            raise Error("invalid application control flow")
        self._value = value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value


struct OperationId(Copyable):
    """A stable logical operation key paired with one unique generation."""

    var key: String
    var generation: Int

    def __init__(out self, var key: String, generation: Int):
        self.key = key^
        self.generation = max(generation, 0)

    def equals(self, other: Self) -> Bool:
        return self.key == other.key and self.generation == other.generation


struct CancellationToken(Copyable):
    """A value token checked against an owning `OperationTracker`."""

    var operation: OperationId

    def __init__(out self, operation: OperationId):
        self.operation = operation.copy()


struct _OperationGeneration(Copyable):
    var key: String
    var generation: Int

    def __init__(out self, var key: String, generation: Int):
        self.key = key^
        self.generation = generation


struct OperationTracker(Copyable):
    """Own generations used to reject stale or cancelled background results."""

    var generations: List[_OperationGeneration]

    def __init__(out self):
        self.generations = List[_OperationGeneration]()

    def _index(self, key: StringSlice) -> Int:
        for index in range(len(self.generations)):
            if self.generations[index].key == key:
                return index
        return -1

    def begin(mut self, var key: String) raises -> OperationId:
        """Start a new generation, invalidating older work with this key."""
        var index = self._index(key)
        if index < 0:
            self.generations.append(_OperationGeneration(key^, 0))
            return OperationId(self.generations[len(self.generations) - 1].key, 0)
        if self.generations[index].generation == Int.MAX:
            raise Error("operation generation exhausted for key: ", key)
        self.generations[index].generation += 1
        return OperationId(
            self.generations[index].key,
            self.generations[index].generation,
        )

    def cancel(mut self, key: StringSlice) raises:
        """Invalidate the current generation without starting replacement work."""
        var index = self._index(key)
        if index < 0:
            return
        if self.generations[index].generation == Int.MAX:
            raise Error("operation generation exhausted for key: ", key)
        self.generations[index].generation += 1

    def is_current(self, operation: OperationId) -> Bool:
        var index = self._index(operation.key)
        return index >= 0 and self.generations[index].generation == operation.generation

    def is_cancelled(self, token: CancellationToken) -> Bool:
        return not self.is_current(token.operation)


struct Command[E: Deinitable & Movable](Movable):
    """A typed effect request carrying optional stale-result metadata."""

    var effect: Self.E
    var operation: Optional[OperationId]

    def __init__(out self, var effect: Self.E):
        self.effect = effect^
        self.operation = None

    @staticmethod
    def tracked(var effect: Self.E, operation: OperationId) -> Self:
        var result = Self(effect^)
        result.operation = operation.copy()
        return result^

    def cancellation_token(self) -> Optional[CancellationToken]:
        if self.operation:
            return CancellationToken(self.operation.value())
        return None


struct UpdateResult[E: Deinitable & Movable](Movable):
    """One sequential update's redraw decision and typed effect requests."""

    var redraw: Bool
    var control: ControlFlow
    var commands: List[Command[Self.E]]

    def __init__(
        out self,
        redraw: Bool = True,
        var commands: List[Command[Self.E]] = List[Command[Self.E]](),
        control: ControlFlow = ControlFlow.CONTINUE,
    ):
        self.redraw = redraw
        self.control = control
        self.commands = commands^

    @staticmethod
    def unchanged() -> Self:
        return Self(False)

    @staticmethod
    def redraw_only() -> Self:
        return Self(True)

    @staticmethod
    def exit(redraw: Bool = False) -> Self:
        return Self(redraw, control=ControlFlow.EXIT)

    def take_commands(mut self) -> List[Command[Self.E]]:
        """Transfer commands while leaving this result valid for destruction."""
        var commands = self.commands^
        self.commands = List[Command[Self.E]]()
        return commands^


struct Subscription[E: Deinitable & Movable](Movable):
    """A declarative, stable-ID request for an ongoing typed effect source."""

    var id: String
    var revision: Int
    var effect: Self.E

    def __init__(
        out self,
        var id: String,
        var effect: Self.E,
        revision: Int = 0,
    ):
        self.id = id^
        self.revision = max(revision, 0)
        self.effect = effect^


struct _ActiveSubscription(Copyable):
    var id: String
    var revision: Int

    def __init__(out self, var id: String, revision: Int):
        self.id = id^
        self.revision = revision


struct SubscriptionDelta[E: Deinitable & Movable](Movable):
    """Sources to start and stable IDs whose existing source must stop."""

    var starts: List[Subscription[Self.E]]
    var stops: List[String]

    def __init__(
        out self,
        var starts: List[Subscription[Self.E]] = List[Subscription[Self.E]](),
        var stops: List[String] = List[String](),
    ):
        self.starts = starts^
        self.stops = stops^


struct SubscriptionTracker(Copyable):
    """Reconcile declarative subscriptions without owning runtime tasks."""

    var active: List[_ActiveSubscription]

    def __init__(out self):
        self.active = List[_ActiveSubscription]()

    def _active_index(self, id: StringSlice) -> Int:
        for index in range(len(self.active)):
            if self.active[index].id == id:
                return index
        return -1

    def active_count(self) -> Int:
        return len(self.active)

    def reconcile[
        E: Deinitable & Movable
    ](mut self, var desired: List[Subscription[E]]) raises -> SubscriptionDelta[E]:
        """Compute starts/stops; adapters apply the returned delta."""
        for index in range(len(desired)):
            if desired[index].id == "":
                raise Error("subscription ID must not be empty")
            for earlier in range(index):
                if desired[earlier].id == desired[index].id:
                    raise Error("duplicate subscription ID: ", desired[index].id)

        var stops = List[String]()
        for active_index in range(len(self.active)):
            var found = -1
            for desired_index in range(len(desired)):
                if desired[desired_index].id == self.active[active_index].id:
                    found = desired_index
                    break
            if (
                found < 0
                or desired[found].revision != self.active[active_index].revision
            ):
                stops.append(self.active[active_index].id)

        var starts = List[Subscription[E]]()
        var next_active = List[_ActiveSubscription]()
        while len(desired) > 0:
            var subscription = desired.pop(0)
            var existing = self._active_index(subscription.id)
            var must_start = (
                existing < 0 or self.active[existing].revision != subscription.revision
            )
            next_active.append(
                _ActiveSubscription(subscription.id, subscription.revision)
            )
            if must_start:
                starts.append(subscription^)

        self.active = next_active^
        return SubscriptionDelta(starts^, stops^)


struct OperationResult[M: Deinitable & Movable](Movable):
    """A message produced by one operation generation."""

    var operation: OperationId
    var message: Optional[Self.M]

    def __init__(out self, operation: OperationId, var message: Self.M):
        self.operation = operation.copy()
        self.message = message^


def accept_operation_result[
    M: Deinitable & Movable
](tracker: OperationTracker, var result: OperationResult[M]) -> Optional[M]:
    """Return the message only while its operation generation is current."""
    if tracker.is_current(result.operation):
        return result.message.take()
    return None
