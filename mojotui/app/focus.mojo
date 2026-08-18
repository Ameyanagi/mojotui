"""Stable focus identities, traversal, and nested modal scopes."""

from std.collections import List, Optional


struct FocusId(Copyable):
    """A stable application-defined identity for one focusable target."""

    var value: String

    def __init__(out self, var value: String):
        self.value = value^

    def equals(self, other: Self) -> Bool:
        return self.value == other.value


struct _FocusScope(Copyable):
    var id: String
    var members: List[FocusId]
    var restore: FocusId
    var has_restore: Bool

    def __init__(
        out self,
        var id: String,
        var members: List[FocusId],
        restore: FocusId,
        has_restore: Bool,
    ):
        self.id = id^
        self.members = members^
        self.restore = restore.copy()
        self.has_restore = has_restore


struct FocusManager(Copyable):
    """Own traversal order while modal scopes temporarily constrain focus."""

    var order: List[FocusId]
    var scopes: List[_FocusScope]
    var focused: FocusId
    var has_focus: Bool

    def __init__(out self):
        self.order = List[FocusId]()
        self.scopes = List[_FocusScope]()
        self.focused = FocusId("")
        self.has_focus = False

    @staticmethod
    def _validate_ids(ids: List[FocusId]) raises:
        for index in range(len(ids)):
            if ids[index].value == "":
                raise Error("focus ID must not be empty")
            for earlier in range(index):
                if ids[earlier].equals(ids[index]):
                    raise Error("duplicate focus ID: ", ids[index].value)

    def _active_count(self) -> Int:
        if len(self.scopes) > 0:
            return len(self.scopes[len(self.scopes) - 1].members)
        return len(self.order)

    def _active_at(self, index: Int) -> FocusId:
        if len(self.scopes) > 0:
            return self.scopes[len(self.scopes) - 1].members[index].copy()
        return self.order[index].copy()

    def _active_index(self, id: FocusId) -> Int:
        for index in range(self._active_count()):
            if self._active_at(index).equals(id):
                return index
        return -1

    def _normalize(mut self):
        if self.has_focus and self._active_index(self.focused) >= 0:
            return
        if self._active_count() == 0:
            self.focused = FocusId("")
            self.has_focus = False
        else:
            self.focused = self._active_at(0)
            self.has_focus = True

    def set_order(mut self, var order: List[FocusId]) raises:
        """Replace root traversal order while preserving valid focus."""
        Self._validate_ids(order)
        self.order = order^
        self._normalize()

    def current(self) -> Optional[FocusId]:
        if self.has_focus:
            return self.focused.copy()
        return None

    def focus(mut self, id: FocusId) -> Bool:
        """Focus an active target; modal scopes reject outside targets."""
        if self._active_index(id) < 0:
            return False
        self.focused = id.copy()
        self.has_focus = True
        return True

    def next(mut self):
        var count = self._active_count()
        if count == 0:
            self._normalize()
            return
        var index = self._active_index(self.focused) if self.has_focus else -1
        self.focused = self._active_at((index + 1) % count)
        self.has_focus = True

    def previous(mut self):
        var count = self._active_count()
        if count == 0:
            self._normalize()
            return
        var index = self._active_index(self.focused) if self.has_focus else 0
        self.focused = self._active_at((index + count - 1) % count)
        self.has_focus = True

    def push_scope(mut self, var id: String, var members: List[FocusId]) raises:
        """Enter a modal scope and remember the prior focused target."""
        if id == "":
            raise Error("focus scope ID must not be empty")
        for index in range(len(self.scopes)):
            if self.scopes[index].id == id:
                raise Error("duplicate focus scope ID: ", id)
        Self._validate_ids(members)
        self.scopes.append(_FocusScope(id^, members^, self.focused, self.has_focus))
        self.has_focus = False
        self._normalize()

    def pop_scope(mut self) -> Bool:
        """Leave the innermost modal scope and restore valid prior focus."""
        if len(self.scopes) == 0:
            return False
        var scope = self.scopes.pop()
        self.has_focus = False
        if scope.has_restore and self._active_index(scope.restore) >= 0:
            self.focused = scope.restore.copy()
            self.has_focus = True
        self._normalize()
        return True

    def scope_depth(self) -> Int:
        return len(self.scopes)
