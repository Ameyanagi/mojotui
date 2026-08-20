"""Small form widgets composed from the editor and rendering core."""

from ..core.buffer import Buffer
from ..core.cell import Cell
from ..core.geometry import Point, Rect
from ..core.style import Style, StylePatch
from ..core.widget import StatefulWidget, Widget
from ..editor.clipboard import Clipboard
from ..editor.commands import (
    EditorCommand,
    EditorCommandKind,
    execute_editor_command,
)
from ..editor.widget import Editor, EditorState, WrapMode
from ..text.rich import Line, render_line
from ..widgets.basic import Block


struct TextInput(Copyable, StatefulWidget):
    """A one-line input sharing the editor's transactions and selections."""

    comptime State = EditorState

    var placeholder: Line
    var focused: Bool
    var style: Style
    var placeholder_style: Style
    var cursor_style: Style
    var block: Block
    var draw_block: Bool

    def __init__(
        out self,
        placeholder: Line = Line(),
        focused: Bool = False,
        style: Style = Style.plain(),
        placeholder_style: Style = Style(modifiers=Style.DIM),
        cursor_style: Style = Style(modifiers=Style.REVERSED),
    ):
        self.placeholder = placeholder.copy()
        self.focused = focused
        self.style = style.copy()
        self.placeholder_style = placeholder_style.copy()
        self.cursor_style = cursor_style.copy()
        self.block = Block()
        self.draw_block = False

    @staticmethod
    def with_block(
        block: Block,
        placeholder: Line = Line(),
        focused: Bool = False,
        style: Style = Style.plain(),
        placeholder_style: Style = Style(modifiers=Style.DIM),
        cursor_style: Style = Style(modifiers=Style.REVERSED),
    ) -> Self:
        var result = Self(placeholder, focused, style, placeholder_style, cursor_style)
        result.block = block.copy()
        result.draw_block = True
        return result^

    def render(self, area: Rect, mut buffer: Buffer, mut state: EditorState) raises:
        var visible = buffer.area.intersection(area)
        if visible.is_empty():
            return
        if state.engine.document.byte_length() == 0 and not self.focused:
            buffer.fill(visible, Cell(style=self.style))
            var content = visible.copy()
            if self.draw_block:
                self.block.render(visible, buffer)
                content = self.block.inner(visible)
            if not content.is_empty():
                var placeholder = self.placeholder.copy()
                for index in range(len(placeholder.spans)):
                    placeholder.spans[index].apply_style_patch(
                        StylePatch.from_style(self.placeholder_style)
                    )
                render_line(
                    placeholder,
                    Rect(content.x, content.y, content.width, 1),
                    buffer,
                    base_style=self.style,
                )
            return

        var cursor_style = (
            self.cursor_style.copy() if self.focused else self.style.copy()
        )
        var editor = Editor(
            wrap_mode=WrapMode.NONE,
            style=self.style,
            cursor_style=cursor_style,
        )
        if self.draw_block:
            editor.block = self.block.copy()
            editor.draw_block = True
        editor.render(visible, buffer, state)


def execute_text_input_command[
    C: Clipboard
](mut state: EditorState, command: EditorCommand, mut clipboard: C,) raises -> Bool:
    """Execute an editor command while enforcing the one-line invariant."""
    if command.kind == EditorCommandKind.NEWLINE:
        return False
    if command.kind == EditorCommandKind.INSERT:
        var text = command.text.replace("\r", "").replace("\n", "")
        return execute_editor_command(
            state.engine, EditorCommand.insert(text^), clipboard
        )
    if command.kind == EditorCommandKind.PASTE:
        var text = clipboard.read().replace("\r", "").replace("\n", "")
        return execute_editor_command(
            state.engine, EditorCommand.insert(text^), clipboard
        )
    return execute_editor_command(state.engine, command, clipboard)


struct TextArea(Copyable, StatefulWidget):
    """A named form wrapper around the full editor widget."""

    comptime State = EditorState

    var editor: Editor

    def __init__(
        out self,
        wrap_mode: WrapMode = WrapMode.SOFT,
        tab_width: Int = 4,
        show_line_numbers: Bool = False,
        style: Style = Style.plain(),
    ):
        self.editor = Editor(
            wrap_mode=wrap_mode,
            tab_width=tab_width,
            show_line_numbers=show_line_numbers,
            style=style,
        )

    def render(self, area: Rect, mut buffer: Buffer, mut state: EditorState) raises:
        self.editor.render(area, buffer, state)


struct Checkbox(Copyable, Widget):
    """A checkbox whose boolean value remains application-owned."""

    var label: Line
    var checked: Bool
    var focused: Bool
    var style: Style
    var focused_style: Style

    def __init__(
        out self,
        label: Line,
        checked: Bool = False,
        focused: Bool = False,
        style: Style = Style.plain(),
        focused_style: Style = Style(modifiers=Style.REVERSED),
    ):
        self.label = label.copy()
        self.checked = checked
        self.focused = focused
        self.style = style.copy()
        self.focused_style = focused_style.copy()

    def render(self, area: Rect, mut buffer: Buffer):
        var visible = buffer.area.intersection(area)
        if visible.is_empty():
            return
        var active_style = (
            self.focused_style.copy() if self.focused else self.style.copy()
        )
        buffer.fill(
            Rect(visible.x, visible.y, visible.width, 1),
            Cell(style=active_style),
        )
        _ = buffer.set_cell(
            Point(visible.x, visible.y),
            Cell("☑" if self.checked else "☐", style=active_style),
        )
        if visible.width > 2:
            render_line(
                self.label,
                Rect(visible.x + 2, visible.y, visible.width - 2, 1),
                buffer,
            )


struct Button(Copyable, Widget):
    """A compact button with explicit focus supplied by application state."""

    var label: Line
    var focused: Bool
    var style: Style
    var focused_style: Style

    def __init__(
        out self,
        label: Line,
        focused: Bool = False,
        style: Style = Style.plain(),
        focused_style: Style = Style(modifiers=Style.REVERSED),
    ):
        self.label = label.copy()
        self.focused = focused
        self.style = style.copy()
        self.focused_style = focused_style.copy()

    def render(self, area: Rect, mut buffer: Buffer):
        var visible = buffer.area.intersection(area)
        if visible.is_empty():
            return
        var active_style = (
            self.focused_style.copy() if self.focused else self.style.copy()
        )
        buffer.fill(
            Rect(visible.x, visible.y, visible.width, 1),
            Cell(style=active_style),
        )
        var decorated = (
            Line.from_text(
                "[ " + self.label.spans[0].content + " ]", active_style
            ) if len(self.label.spans)
            == 1 else self.label.copy()
        )
        render_line(decorated, Rect(visible.x, visible.y, visible.width, 1), buffer)
