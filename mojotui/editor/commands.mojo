"""Conventional editor commands over transactions, selections, and clipboards."""

from std.collections import List

from .clipboard import Clipboard
from .history import Edit, EditorEngine
from .selection import (
    Selection,
    SelectionSet,
    move_selection_left,
    move_selection_right,
    move_selection_vertical,
    next_grapheme_offset,
    previous_grapheme_offset,
)


struct EditorCommandKind:
    comptime INSERT = 0
    comptime MOVE_LEFT = 1
    comptime MOVE_RIGHT = 2
    comptime MOVE_UP = 3
    comptime MOVE_DOWN = 4
    comptime LINE_START = 5
    comptime LINE_END = 6
    comptime DOCUMENT_START = 7
    comptime DOCUMENT_END = 8
    comptime DELETE_BACKWARD = 9
    comptime DELETE_FORWARD = 10
    comptime NEWLINE = 11
    comptime SELECT_ALL = 12
    comptime COPY = 13
    comptime CUT = 14
    comptime PASTE = 15
    comptime UNDO = 16
    comptime REDO = 17


struct EditorCommand(Copyable):
    """A semantic edit/navigation command independent of physical key bindings."""

    var kind: Int
    var text: String
    var extend: Bool

    def __init__(out self, kind: Int, var text: String = "", extend: Bool = False):
        self.kind = kind
        self.text = text^
        self.extend = extend

    @staticmethod
    def insert(var text: String) -> Self:
        return Self(EditorCommandKind.INSERT, text^)

    @staticmethod
    def motion(kind: Int, extend: Bool = False) -> Self:
        return Self(kind, extend=extend)


def _replace_selections(mut engine: EditorEngine, var text: String) raises -> Bool:
    var edits = List[Edit]()
    for index in range(len(engine.selections.selections)):
        var selection = engine.selections.selections[index].copy()
        edits.append(Edit(selection.start(), selection.end(), text.copy()))
    return engine.apply(edits^)


def _delete_backward(mut engine: EditorEngine) raises -> Bool:
    var edits = List[Edit]()
    for index in range(len(engine.selections.selections)):
        var selection = engine.selections.selections[index].copy()
        var start = selection.start()
        var end = selection.end()
        if selection.is_empty():
            start = previous_grapheme_offset(engine.document, selection.head)
        if start != end:
            edits.append(Edit(start, end, ""))
    return engine.apply(edits^)


def _delete_forward(mut engine: EditorEngine) raises -> Bool:
    var edits = List[Edit]()
    for index in range(len(engine.selections.selections)):
        var selection = engine.selections.selections[index].copy()
        var start = selection.start()
        var end = selection.end()
        if selection.is_empty():
            end = next_grapheme_offset(engine.document, selection.head)
        if start != end:
            edits.append(Edit(start, end, ""))
    return engine.apply(edits^)


def selected_text(engine: EditorEngine) raises -> String:
    """Join non-empty selections in document order with newlines."""
    var result = String()
    var wrote = False
    for index in range(len(engine.selections.selections)):
        var selection = engine.selections.selections[index].copy()
        if selection.is_empty():
            continue
        if wrote:
            result += "\n"
        result += engine.document.slice(selection.start(), selection.end())
        wrote = True
    return result^


def _move_absolute(mut engine: EditorEngine, kind: Int, extend: Bool) raises:
    for index in range(len(engine.selections.selections)):
        var selection = engine.selections.selections[index].copy()
        var target: Int
        if kind == EditorCommandKind.DOCUMENT_START:
            target = 0
        elif kind == EditorCommandKind.DOCUMENT_END:
            target = engine.document.byte_length()
        else:
            var line = engine.document.line_of_offset(selection.head)
            target = engine.document.line_start(
                line
            ) if kind == EditorCommandKind.LINE_START else engine.document.line_end(
                line
            )
        selection.head = target
        selection.desired_column = -1
        if not extend:
            selection.anchor = target
        engine.selections.selections[index] = selection.copy()
    engine.selections.normalize(engine.document)


def _move_relative(mut engine: EditorEngine, kind: Int, extend: Bool) raises:
    for index in range(len(engine.selections.selections)):
        var selection = engine.selections.selections[index].copy()
        if kind == EditorCommandKind.MOVE_LEFT:
            move_selection_left(engine.document, selection, extend)
        elif kind == EditorCommandKind.MOVE_RIGHT:
            move_selection_right(engine.document, selection, extend)
        elif kind == EditorCommandKind.MOVE_UP:
            move_selection_vertical(engine.document, selection, -1, extend)
        else:
            move_selection_vertical(engine.document, selection, 1, extend)
        engine.selections.selections[index] = selection.copy()
    engine.selections.normalize(engine.document)


def execute_editor_command[
    C: Clipboard
](mut engine: EditorEngine, command: EditorCommand, mut clipboard: C,) raises -> Bool:
    """Execute one semantic command; return whether it was handled."""
    if command.kind == EditorCommandKind.INSERT:
        return _replace_selections(engine, command.text.copy())
    if command.kind == EditorCommandKind.NEWLINE:
        return _replace_selections(engine, "\n")
    if command.kind == EditorCommandKind.DELETE_BACKWARD:
        return _delete_backward(engine)
    if command.kind == EditorCommandKind.DELETE_FORWARD:
        return _delete_forward(engine)
    if command.kind == EditorCommandKind.UNDO:
        return engine.undo()
    if command.kind == EditorCommandKind.REDO:
        return engine.redo()
    if command.kind == EditorCommandKind.SELECT_ALL:
        engine.selections = SelectionSet([Selection(0, engine.document.byte_length())])
        return True
    if command.kind == EditorCommandKind.COPY:
        var text = selected_text(engine)
        if text == "":
            return False
        clipboard.write(text^)
        return True
    if command.kind == EditorCommandKind.CUT:
        var text = selected_text(engine)
        if text == "":
            return False
        clipboard.write(text^)
        return _replace_selections(engine, "")
    if command.kind == EditorCommandKind.PASTE:
        var text = clipboard.read()
        return _replace_selections(engine, text^)
    if (
        command.kind == EditorCommandKind.MOVE_LEFT
        or command.kind == EditorCommandKind.MOVE_RIGHT
        or command.kind == EditorCommandKind.MOVE_UP
        or command.kind == EditorCommandKind.MOVE_DOWN
    ):
        _move_relative(engine, command.kind, command.extend)
        return True
    if (
        command.kind == EditorCommandKind.LINE_START
        or command.kind == EditorCommandKind.LINE_END
        or command.kind == EditorCommandKind.DOCUMENT_START
        or command.kind == EditorCommandKind.DOCUMENT_END
    ):
        _move_absolute(engine, command.kind, command.extend)
        return True
    return False
