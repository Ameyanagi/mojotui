"""Contextual, timed key sequences mapped to typed semantic actions."""

from std.collections import List, Optional

from ..event.input import KeyCode, KeyEvent, KeyModifiers


struct KeyChord(Copyable):
    """The comparable portion of a parsed key event."""

    var code: KeyCode
    var text: String
    var modifiers: KeyModifiers

    def __init__(
        out self,
        code: KeyCode,
        var text: String = "",
        modifiers: KeyModifiers = KeyModifiers.NONE,
    ):
        self.code = code
        self.text = text^
        self.modifiers = modifiers

    @staticmethod
    def from_event(event: KeyEvent) -> Self:
        return Self(event.code, event.text, event.modifiers)

    @staticmethod
    def character(
        var text: String, modifiers: KeyModifiers = KeyModifiers.NONE
    ) -> Self:
        return Self(KeyEvent.CHARACTER, text^, modifiers)

    def equals(self, other: Self) -> Bool:
        return (
            self.code == other.code
            and self.text == other.text
            and self.modifiers == other.modifiers
        )


struct _KeyBinding[A: Copyable & Deinitable](Copyable):
    var context: String
    var sequence: List[KeyChord]
    var action: Self.A

    def __init__(
        out self,
        var context: String,
        var sequence: List[KeyChord],
        action: Self.A,
    ):
        self.context = context^
        self.sequence = sequence^
        self.action = action.copy()


struct _KeyMatch(Copyable):
    var exact: Int
    var has_longer_prefix: Bool
    var any_prefix: Bool

    def __init__(
        out self,
        exact: Int = -1,
        has_longer_prefix: Bool = False,
        any_prefix: Bool = False,
    ):
        self.exact = exact
        self.has_longer_prefix = has_longer_prefix
        self.any_prefix = any_prefix


struct KeyResolution[A: Copyable & Deinitable](Copyable):
    """Zero or more actions plus whether the current sequence is pending."""

    var actions: List[Self.A]
    var pending: Bool
    var consumed: Bool

    def __init__(
        out self,
        var actions: List[Self.A] = List[Self.A](),
        pending: Bool = False,
        consumed: Bool = False,
    ):
        self.actions = actions^
        self.pending = pending
        self.consumed = consumed


struct KeymapState[A: Copyable & Deinitable](Copyable):
    """Caller-owned in-progress sequence and ambiguous exact match."""

    var context: String
    var pending: List[KeyChord]
    var pending_exact: Optional[Self.A]
    var deadline_ns: Int

    def __init__(out self):
        self.context = ""
        self.pending = List[KeyChord]()
        self.pending_exact = None
        self.deadline_ns = 0

    def clear(mut self):
        self.context = ""
        self.pending.clear()
        self.pending_exact = None
        self.deadline_ns = 0


struct Keymap[A: Copyable & Deinitable](Copyable):
    """A static-action keymap with contextual bindings and sequence timeout."""

    var bindings: List[_KeyBinding[Self.A]]
    var timeout_ns: Int

    def __init__(out self, timeout_ns: Int = 500_000_000):
        self.bindings = List[_KeyBinding[Self.A]]()
        self.timeout_ns = max(timeout_ns, 0)

    @staticmethod
    def _same_sequence(left: List[KeyChord], right: List[KeyChord]) -> Bool:
        if len(left) != len(right):
            return False
        for index in range(len(left)):
            if not left[index].equals(right[index]):
                return False
        return True

    def bind(
        mut self,
        var context: String,
        var sequence: List[KeyChord],
        action: Self.A,
    ) raises:
        """Add one binding; an empty context denotes a global binding."""
        if len(sequence) == 0:
            raise Error("key sequence must not be empty")
        for index in range(len(self.bindings)):
            if self.bindings[index].context == context and Self._same_sequence(
                self.bindings[index].sequence, sequence
            ):
                raise Error("duplicate key binding in context: ", context)
        self.bindings.append(_KeyBinding(context^, sequence^, action))

    def bind_key(
        mut self,
        var context: String,
        chord: KeyChord,
        action: Self.A,
    ) raises:
        self.bind(context^, [chord.copy()], action)

    @staticmethod
    def _is_prefix(sequence: List[KeyChord], prefix: List[KeyChord]) -> Bool:
        if len(prefix) > len(sequence):
            return False
        for index in range(len(prefix)):
            if not sequence[index].equals(prefix[index]):
                return False
        return True

    def _match(self, context: StringSlice, pending: List[KeyChord]) -> _KeyMatch:
        var result = _KeyMatch()
        for index in range(len(self.bindings)):
            if self.bindings[index].context != context:
                continue
            if not Self._is_prefix(self.bindings[index].sequence, pending):
                continue
            result.any_prefix = True
            if len(self.bindings[index].sequence) == len(pending):
                result.exact = index
            else:
                result.has_longer_prefix = True
        return result^

    def _contextual_match(
        self, context: StringSlice, pending: List[KeyChord]
    ) -> _KeyMatch:
        var contextual = self._match(context, pending)
        if contextual.any_prefix or context == "":
            return contextual^
        return self._match("", pending)

    def _deadline(self, now_ns: Int) -> Int:
        if self.timeout_ns > Int.MAX - max(now_ns, 0):
            return Int.MAX
        return max(now_ns, 0) + self.timeout_ns

    def resolve(
        self,
        mut state: KeymapState[Self.A],
        chord: KeyChord,
        context: StringSlice,
        now_ns: Int,
    ) -> KeyResolution[Self.A]:
        """Resolve one chord, retrying it after an invalid longer prefix."""
        var actions = List[Self.A]()
        if state.context != context:
            state.clear()
        elif len(state.pending) > 0 and now_ns >= state.deadline_ns:
            if state.pending_exact:
                actions.append(state.pending_exact.value().copy())
            state.clear()

        state.context = String(context)
        state.pending.append(chord.copy())
        var matched = self._contextual_match(context, state.pending)
        if not matched.any_prefix and len(state.pending) > 1:
            state.clear()
            state.context = String(context)
            state.pending.append(chord.copy())
            matched = self._contextual_match(context, state.pending)

        if not matched.any_prefix:
            state.clear()
            return KeyResolution(actions^, consumed=len(actions) > 0)

        if matched.exact >= 0 and not matched.has_longer_prefix:
            actions.append(self.bindings[matched.exact].action.copy())
            state.clear()
            return KeyResolution(actions^, consumed=True)

        state.pending_exact = None
        if matched.exact >= 0:
            state.pending_exact = self.bindings[matched.exact].action.copy()
        state.deadline_ns = self._deadline(now_ns)
        return KeyResolution(actions^, pending=True, consumed=True)

    def flush(
        self, mut state: KeymapState[Self.A], now_ns: Int
    ) -> KeyResolution[Self.A]:
        """Resolve an ambiguous exact match once its timeout elapses."""
        if len(state.pending) == 0:
            return KeyResolution[Self.A]()
        if now_ns < state.deadline_ns:
            return KeyResolution[Self.A](pending=True)
        var actions = List[Self.A]()
        if state.pending_exact:
            actions.append(state.pending_exact.value().copy())
        state.clear()
        return KeyResolution(actions^, consumed=len(actions) > 0)
