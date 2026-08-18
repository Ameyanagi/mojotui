"""Transactional multi-range editing with bounded undo and redo."""

from std.collections import List

from .document import Document
from .selection import Selection, SelectionSet


struct Edit(Copyable):
    """Replace `[start, end)` with UTF-8 text in the pre-transaction document."""

    var start: Int
    var end: Int
    var text: String

    def __init__(out self, start: Int, end: Int, var text: String):
        self.start = start
        self.end = end
        self.text = text^


struct _AppliedEdit(Copyable):
    var start: Int
    var before: String
    var after: String

    def __init__(out self, start: Int, var before: String, var after: String):
        self.start = start
        self.before = before^
        self.after = after^

    def byte_cost(self) -> Int:
        return self.before.byte_length() + self.after.byte_length()


struct _Transaction(Copyable):
    var edits: List[_AppliedEdit]
    var before_selections: SelectionSet
    var after_selections: SelectionSet
    var byte_cost: Int

    def __init__(
        out self,
        var edits: List[_AppliedEdit],
        before_selections: SelectionSet,
        after_selections: SelectionSet,
    ):
        self.edits = edits^
        self.before_selections = before_selections.copy()
        self.after_selections = after_selections.copy()
        self.byte_cost = 0
        for index in range(len(self.edits)):
            var cost = self.edits[index].byte_cost()
            if cost > Int.MAX - self.byte_cost:
                self.byte_cost = Int.MAX
            else:
                self.byte_cost += cost


struct EditorEngine(Movable):
    """A document, normalized selections, and bounded transactional history."""

    var document: Document
    var selections: SelectionSet
    var undo_stack: List[_Transaction]
    var redo_stack: List[_Transaction]
    var undo_bytes: Int
    var max_transactions: Int
    var max_history_bytes: Int

    def __init__(
        out self,
        var text: String = "",
        max_transactions: Int = 1000,
        max_history_bytes: Int = 64 * 1024 * 1024,
    ):
        self.document = Document(text^)
        self.selections = SelectionSet()
        self.undo_stack = List[_Transaction]()
        self.redo_stack = List[_Transaction]()
        self.undo_bytes = 0
        self.max_transactions = max(max_transactions, 0)
        self.max_history_bytes = max(max_history_bytes, 0)

    @staticmethod
    def _sort_descending(mut edits: List[Edit]):
        for index in range(1, len(edits)):
            var value = edits[index].copy()
            var cursor = index
            while cursor > 0:
                var previous = edits[cursor - 1].copy()
                if previous.start > value.start or (
                    previous.start == value.start and previous.end >= value.end
                ):
                    break
                edits[cursor] = previous.copy()
                cursor -= 1
            edits[cursor] = value.copy()

    def _validate_edits(self, edits: List[Edit]) raises:
        for index in range(len(edits)):
            var edit = edits[index].copy()
            if (
                edit.start < 0
                or edit.end < edit.start
                or edit.end > self.document.byte_length()
                or not self.document.is_utf8_boundary(edit.start)
                or not self.document.is_utf8_boundary(edit.end)
            ):
                raise Error("transaction edit range is invalid")
            if index > 0:
                var previous = edits[index - 1].copy()
                if edit.end > previous.start:
                    raise Error("transaction edits overlap")
                if (
                    edit.start == edit.end
                    and previous.start == previous.end
                    and edit.start == previous.start
                ):
                    raise Error("transaction has ambiguous inserts at one offset")

    @staticmethod
    def _result_selections(edits: List[_AppliedEdit]) -> SelectionSet:
        var selections = List[Selection]()
        for index in range(len(edits)):
            var edit = edits[index].copy()
            var adjusted_start = edit.start
            for other_index in range(len(edits)):
                var other = edits[other_index].copy()
                if other.start < edit.start:
                    adjusted_start += (
                        other.after.byte_length() - other.before.byte_length()
                    )
            selections.append(
                Selection.caret(adjusted_start + edit.after.byte_length())
            )
        return SelectionSet(selections^)

    def _trim_history(mut self):
        while (
            len(self.undo_stack) > self.max_transactions
            or self.undo_bytes > self.max_history_bytes
        ):
            if len(self.undo_stack) == 0:
                self.undo_bytes = 0
                return
            var removed = self.undo_stack.pop(0)
            self.undo_bytes = max(self.undo_bytes - removed.byte_cost, 0)

    @staticmethod
    def _saturating_cost_add(left: Int, right: Int) -> Int:
        if right > Int.MAX - left:
            return Int.MAX
        return left + right

    def apply(mut self, var edits: List[Edit]) raises -> Bool:
        """Validate then apply non-overlapping edits from highest offset down."""
        if len(edits) == 0:
            return False
        Self._sort_descending(edits)
        self._validate_edits(edits)
        var before_selections = self.selections.copy()
        var applied = List[_AppliedEdit]()
        for index in range(len(edits)):
            var edit = edits[index].copy()
            if edit.start == edit.end and edit.text == "":
                continue
            var start = edit.start
            var end = edit.end
            var inserted = edit.text.copy()
            var removed = self.document.replace(start, end, inserted.copy())
            applied.append(_AppliedEdit(start, removed^, inserted^))
        if len(applied) == 0:
            return False

        var after_selections = Self._result_selections(applied)
        after_selections.normalize(self.document)
        self.selections = after_selections.copy()
        var transaction = _Transaction(applied^, before_selections, after_selections)
        self.redo_stack.clear()
        if self.max_transactions > 0 and self.max_history_bytes > 0:
            self.undo_bytes = Self._saturating_cost_add(
                self.undo_bytes, transaction.byte_cost
            )
            self.undo_stack.append(transaction^)
            self._trim_history()
        return True

    def insert(mut self, offset: Int, var text: String) raises -> Bool:
        return self.apply([Edit(offset, offset, text^)])

    def delete(mut self, start: Int, end: Int) raises -> Bool:
        return self.apply([Edit(start, end, "")])

    def replace(mut self, start: Int, end: Int, var text: String) raises -> Bool:
        return self.apply([Edit(start, end, text^)])

    def can_undo(self) -> Bool:
        return len(self.undo_stack) > 0

    def can_redo(self) -> Bool:
        return len(self.redo_stack) > 0

    def undo(mut self) raises -> Bool:
        if len(self.undo_stack) == 0:
            return False
        var transaction = self.undo_stack.pop()
        for reverse_index in range(len(transaction.edits)):
            var index = len(transaction.edits) - reverse_index - 1
            var edit = transaction.edits[index].copy()
            _ = self.document.replace(
                edit.start,
                edit.start + edit.after.byte_length(),
                edit.before,
            )
        self.selections = transaction.before_selections.copy()
        self.undo_bytes = max(self.undo_bytes - transaction.byte_cost, 0)
        self.redo_stack.append(transaction^)
        return True

    def redo(mut self) raises -> Bool:
        if len(self.redo_stack) == 0:
            return False
        var transaction = self.redo_stack.pop()
        for index in range(len(transaction.edits)):
            var edit = transaction.edits[index].copy()
            _ = self.document.replace(
                edit.start,
                edit.start + edit.before.byte_length(),
                edit.after,
            )
        self.selections = transaction.after_selections.copy()
        self.undo_bytes = Self._saturating_cost_add(
            self.undo_bytes, transaction.byte_cost
        )
        self.undo_stack.append(transaction^)
        self._trim_history()
        return True

    def clear_history(mut self):
        self.undo_stack.clear()
        self.redo_stack.clear()
        self.undo_bytes = 0
