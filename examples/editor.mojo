"""Interactive typed text editor built from Mojotui's public APIs.

Run `pixi run editor -- PATH` to edit a UTF-8 file. With no path, the example
opens an untitled in-memory document. Ctrl-S saves, Ctrl-Q exits, Ctrl-Z and
Ctrl-Y traverse history, Ctrl-A/C/X/V use the application-owned clipboard,
and bracketed paste inserts terminal paste events as one transaction.
"""

from std.collections import List as MojoList, Optional
from std.sys import argv
from std.utils import Variant

from mojotui import (
    AdaptiveColor,
    AnsiBackend,
    Application,
    Block,
    Buffer,
    Cell,
    Color,
    Command,
    Constraint,
    ControllerActionKind,
    DocumentRevision,
    Editor,
    EditorCommand,
    EditorControllerAction,
    EditorState,
    FileMetadata,
    InitResult,
    InputEvent,
    KeyEvent,
    Keymap,
    KeymapState,
    Layout,
    Line,
    LineEnding,
    LoadedFile,
    LocalFileService,
    MemoryClipboard,
    Paragraph,
    PasteEvent,
    ProfiledColor,
    Rect,
    RuntimeAdapter,
    SaveOptions,
    Span,
    Style,
    Subscription,
    SystemClock,
    TerminalApplicationHost,
    TerminalCapabilities,
    Text,
    UpdateResult,
    default_editor_keymap,
    detect_terminal_capabilities,
    display_column,
    execute_editor_command,
    render_line,
    text_input_action,
)


struct LoadFileEffect(Copyable):
    var path: String

    def __init__(out self, var path: String):
        self.path = path^


struct SaveFileEffect(Copyable):
    var path: String
    var temporary_path: String
    var content: String
    var options: SaveOptions
    var revision: DocumentRevision

    def __init__(
        out self,
        var path: String,
        var temporary_path: String,
        var content: String,
        options: SaveOptions,
        revision: DocumentRevision,
    ):
        self.path = path^
        self.temporary_path = temporary_path^
        self.content = content^
        self.options = options.copy()
        self.revision = revision.copy()


comptime EditorExampleEffect = Variant[LoadFileEffect, SaveFileEffect]


struct FileLoadedMessage(Copyable):
    var file: LoadedFile

    def __init__(out self, file: LoadedFile):
        self.file = file.copy()


struct FileSavedMessage(Copyable):
    var metadata: FileMetadata
    var revision: DocumentRevision

    def __init__(
        out self,
        metadata: FileMetadata,
        revision: DocumentRevision,
    ):
        self.metadata = metadata.copy()
        self.revision = revision.copy()


struct FileFailedMessage(Copyable):
    var operation: String
    var path: String
    var detail: String

    def __init__(
        out self,
        var operation: String,
        var path: String,
        var detail: String,
    ):
        self.operation = operation^
        self.path = path^
        self.detail = detail^


comptime EditorExampleMessage = Variant[
    KeyEvent,
    EditorCommand,
    FileLoadedMessage,
    FileSavedMessage,
    FileFailedMessage,
]


struct EditorExampleModel(Movable):
    """Durable editor state; only `EditorApplication.update` mutates it."""

    var editor: EditorState
    var keymap: Keymap[EditorControllerAction]
    var keymap_state: KeymapState[EditorControllerAction]
    var clipboard: MemoryClipboard
    var path: String
    var status: String
    var line_ending: LineEnding
    var had_bom: Bool
    var metadata: Optional[FileMetadata]
    var saved_revision: DocumentRevision
    var save_generation: Int
    var confirming_quit: Bool
    var accent: Color
    var status_background: Color

    def __init__(
        out self,
        var path: String,
        capabilities: TerminalCapabilities = TerminalCapabilities.headless(),
    ) raises:
        var has_path = path != ""
        var initial_text = "" if has_path else (
            "Mojotui editor\n\n"
            "Pass a path to edit a file:\n"
            "  pixi run editor -- notes.txt\n"
        )
        self.editor = EditorState(initial_text^)
        self.keymap = default_editor_keymap()
        self.keymap_state = KeymapState[EditorControllerAction]()
        self.clipboard = MemoryClipboard()
        self.path = path^
        self.status = "loading…" if has_path else "untitled — Ctrl-Q quits"
        self.line_ending = LineEnding.LF
        self.had_bom = False
        self.metadata = None
        self.saved_revision = self.editor.engine.document.revision()
        self.save_generation = 0
        self.confirming_quit = False
        self.accent = AdaptiveColor(
            ProfiledColor.from_rgb(70, 60, 160),
            ProfiledColor.from_rgb(80, 200, 255),
        ).resolve(capabilities)
        self.status_background = AdaptiveColor(
            ProfiledColor.from_rgb(225, 225, 235),
            ProfiledColor.from_rgb(35, 40, 50),
        ).resolve(capabilities)

    def is_modified(self) -> Bool:
        return self.editor.engine.document.revision() != self.saved_revision


def _control_key(key: KeyEvent, text: StringSlice) -> Bool:
    return (
        key.is_activation()
        and key.code == KeyEvent.CHARACTER
        and key.text == text
        and key.modifiers.contains(KeyEvent.CONTROL)
    )


def _apply_editor_action(
    mut model: EditorExampleModel,
    action: EditorControllerAction,
) raises -> Bool:
    if action.kind != ControllerActionKind.EDIT or not action.command:
        return False
    return execute_editor_command(
        model.editor.engine,
        action.command.value(),
        model.clipboard,
    )


def _apply_key(
    mut model: EditorExampleModel,
    key: KeyEvent,
) raises -> Bool:
    # The default map contains only single-key bindings, so it has no timed
    # ambiguity. Applications using sequences should pass clock observations in
    # their own message type and use that timestamp here.
    var resolution = model.keymap.resolve(
        model.keymap_state,
        key,
        "editor",
        0,
    )
    var handled = False
    for index in range(len(resolution.actions)):
        handled = _apply_editor_action(model, resolution.actions[index]) or handled
    if not resolution.consumed:
        var text_action = text_input_action(key)
        if text_action:
            handled = _apply_editor_action(model, text_action.value()) or handled
    return handled


def _save_command(
    mut model: EditorExampleModel,
) -> Optional[Command[EditorExampleEffect]]:
    if model.path == "":
        model.status = "cannot save an untitled buffer — restart with a path"
        return None
    model.save_generation += 1
    var content = model.editor.engine.document.to_string()
    var temporary_path = (
        model.path + ".mojotui." + String(model.save_generation) + ".tmp"
    )
    var options = SaveOptions(
        line_ending=model.line_ending,
        write_bom=model.had_bom,
        expected=model.metadata,
    )
    var effect = SaveFileEffect(
        model.path,
        temporary_path^,
        content^,
        options,
        model.editor.engine.document.revision(),
    )
    model.status = "saving…"
    return Command(EditorExampleEffect(effect^))


def _file_label(model: EditorExampleModel) -> String:
    var label = "[untitled]" if model.path == "" else model.path.copy()
    if model.is_modified():
        label += " *"
    return label^


def render_editor_example(
    model: EditorExampleModel,
    area: Rect,
    mut buffer: Buffer,
) raises:
    """Render one deterministic frame from borrowed application state."""
    if area.width < 32 or area.height < 7:
        Paragraph.with_block(
            Text.from_line(Line.from_text("Resize to at least 32×7")),
            Block.bordered(Line.from_text(" Mojotui editor "), padding_x=1),
        ).render(area, buffer)
        return

    var regions = Layout.vertical(
        [Constraint.fill(), Constraint.length(1), Constraint.length(1)]
    ).split(area)
    if len(regions) < 3:
        return

    var title_style = Style(foreground=model.accent, modifiers=Style.BOLD)
    var editor = Editor.with_block(
        Block.bordered(
            Line.from_text(" " + _file_label(model) + " ", title_style),
            padding_x=1,
        ),
        show_line_numbers=True,
        line_number_style=Style(foreground=model.accent, modifiers=Style.DIM),
    )
    editor.render_readonly(regions[0], buffer, model.editor)

    var primary = model.editor.engine.selections.primary_selection()
    var position = model.editor.engine.document.position_at(primary.head)
    var column = display_column(model.editor.engine.document, primary.head)
    var status_style = Style(
        foreground=model.accent,
        background=model.status_background,
        modifiers=Style.BOLD,
    )
    buffer.fill(regions[1], Cell(" ", style=status_style))
    render_line(
        Line(
            [
                Span(" " + model.status, status_style),
                Span(
                    "  Ln " + String(position.line + 1) + ", Col " + String(column + 1),
                    status_style,
                ),
            ]
        ),
        regions[1],
        buffer,
    )
    render_line(
        Line(
            [
                Span(" Ctrl-S", title_style),
                Span(" save  "),
                Span("Ctrl-Z/Y", title_style),
                Span(" undo/redo  "),
                Span("Ctrl-Q", title_style),
                Span(" quit"),
            ]
        ),
        regions[2],
        buffer,
    )


struct EditorApplication(Application, Copyable):
    comptime Model = EditorExampleModel
    comptime Message = EditorExampleMessage
    comptime Effect = EditorExampleEffect

    var path: String
    var capabilities: TerminalCapabilities

    def __init__(
        out self,
        var path: String = "",
        capabilities: TerminalCapabilities = TerminalCapabilities.headless(),
    ):
        self.path = path^
        self.capabilities = capabilities

    def init(mut self) raises -> InitResult[Self.Model, Self.Effect]:
        var model = EditorExampleModel(self.path, self.capabilities)
        if self.path == "":
            return InitResult[Self.Model, Self.Effect].ready(model^)
        return InitResult[Self.Model, Self.Effect](
            model^,
            [Command(EditorExampleEffect(LoadFileEffect(self.path)))],
        )

    def update(
        mut self,
        mut model: Self.Model,
        var message: Self.Message,
    ) raises -> UpdateResult[Self.Effect]:
        if message.isa[KeyEvent]():
            var key = message[KeyEvent].copy()
            if _control_key(key, "q"):
                if model.is_modified() and not model.confirming_quit:
                    model.confirming_quit = True
                    model.status = (
                        "unsaved changes — press Ctrl-Q again to discard, or Ctrl-S to"
                        " save"
                    )
                    return UpdateResult[Self.Effect].redraw_only()
                return UpdateResult[Self.Effect].exit()
            if key.is_activation():
                model.confirming_quit = False
            if _control_key(key, "s"):
                var command = _save_command(model)
                if command:
                    return UpdateResult[Self.Effect](True, [command.take()])
                return UpdateResult[Self.Effect].redraw_only()
            var before = model.editor.engine.document.version
            var handled = _apply_key(model, key)
            if model.editor.engine.document.version != before:
                model.status = "edited"
            return (
                UpdateResult[Self.Effect]
                .redraw_only() if handled else UpdateResult[Self.Effect]
                .unchanged()
            )

        if message.isa[EditorCommand]():
            var before = model.editor.engine.document.version
            var handled = execute_editor_command(
                model.editor.engine,
                message[EditorCommand],
                model.clipboard,
            )
            if model.editor.engine.document.version != before:
                model.status = "pasted"
            return (
                UpdateResult[Self.Effect]
                .redraw_only() if handled else UpdateResult[Self.Effect]
                .unchanged()
            )

        if message.isa[FileLoadedMessage]():
            var loaded = message[FileLoadedMessage].file.copy()
            model.editor = EditorState(loaded.content)
            model.line_ending = loaded.line_ending
            model.had_bom = loaded.had_bom
            model.metadata = loaded.metadata.copy()
            model.saved_revision = model.editor.engine.document.revision()
            model.confirming_quit = False
            model.status = "loaded"
            return UpdateResult[Self.Effect].redraw_only()

        if message.isa[FileSavedMessage]():
            var saved = message[FileSavedMessage].copy()
            model.metadata = saved.metadata.copy()
            model.saved_revision = saved.revision.copy()
            model.confirming_quit = False
            model.status = "saved" if not model.is_modified() else (
                "saved older snapshot — unsaved edits remain"
            )
            return UpdateResult[Self.Effect].redraw_only()

        var failure = message[FileFailedMessage].copy()
        model.status = (
            failure.operation + ' failed for "' + failure.path + '": ' + failure.detail
        )
        return UpdateResult[Self.Effect].redraw_only()

    def view(self, model: Self.Model, area: Rect, mut buffer: Buffer) raises:
        render_editor_example(model, area, buffer)

    def on_input(
        self,
        model: Self.Model,
        var event: InputEvent,
    ) raises -> Optional[Self.Message]:
        if event.isa[KeyEvent]():
            return EditorExampleMessage(event[KeyEvent].copy())
        if event.isa[PasteEvent]():
            return EditorExampleMessage(EditorCommand.insert(event[PasteEvent].text))
        return None


struct EditorAdapter(RuntimeAdapter):
    """Synchronous file boundary replaceable by a future Mojo task runtime."""

    comptime ApplicationType = EditorApplication

    var service: LocalFileService
    var pending: MojoList[EditorExampleMessage]

    def __init__(out self):
        self.service = LocalFileService()
        self.pending = MojoList[EditorExampleMessage]()

    def execute(
        mut self,
        var command: Command[Self.ApplicationType.Effect],
    ) raises:
        if command.effect.isa[LoadFileEffect]():
            var effect = command.effect[LoadFileEffect].copy()
            try:
                var loaded = self.service.load(effect.path)
                self.pending.append(EditorExampleMessage(FileLoadedMessage(loaded)))
            except error:
                self.pending.append(
                    EditorExampleMessage(
                        FileFailedMessage("load", effect.path, String(error))
                    )
                )
            return

        var effect = command.effect[SaveFileEffect].copy()
        try:
            var metadata = self.service.save_atomic(
                effect.path,
                effect.temporary_path,
                effect.content,
                effect.options,
            )
            self.pending.append(
                EditorExampleMessage(FileSavedMessage(metadata, effect.revision))
            )
        except error:
            self.pending.append(
                EditorExampleMessage(
                    FileFailedMessage("save", effect.path, String(error))
                )
            )

    def start(
        mut self,
        var subscription: Subscription[Self.ApplicationType.Effect],
    ) raises:
        pass

    def stop(mut self, id: StringSlice) raises:
        pass

    def take_messages(mut self) raises -> MojoList[Self.ApplicationType.Message]:
        var result = self.pending^
        self.pending = MojoList[EditorExampleMessage]()
        return result^

    def close(mut self) raises:
        pass

    def close_silently(mut self):
        pass


def run_editor(var path: String = "") raises:
    var capabilities = detect_terminal_capabilities()
    var host = TerminalApplicationHost(
        EditorAdapter(),
        EditorApplication(path^, capabilities),
        SystemClock(),
        AnsiBackend.from_terminal(capabilities=capabilities),
        tick_interval_ms=250,
    )
    host.run()


def main() raises:
    var args = argv()
    var path = String(args[1]) if len(args) > 1 else String()
    run_editor(path^)
