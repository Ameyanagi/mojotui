"""Focused form workflow with validation, submit, and cancel behavior."""

from std.collections import List as MojoList, Optional

from mojotui import (
    AnsiBackend,
    Application,
    Block,
    Buffer,
    Button,
    Checkbox,
    Command,
    Constraint,
    ControlFlow,
    EditorCommand,
    EditorCommandKind,
    EditorState,
    FocusId,
    FocusManager,
    InitResult,
    InputEvent,
    KeyEvent,
    Layout,
    Line,
    MemoryClipboard,
    Rect,
    RuntimeAdapter,
    Subscription,
    SystemClock,
    TerminalApplicationHost,
    TextInput,
    UpdateResult,
    detect_terminal_capabilities,
    execute_text_input_command,
    render_line,
)


def _name_id() -> FocusId:
    return FocusId("name")


def _updates_id() -> FocusId:
    return FocusId("updates")


def _submit_id() -> FocusId:
    return FocusId("submit")


def _cancel_id() -> FocusId:
    return FocusId("cancel")


struct FormModel(Movable):
    var name: EditorState
    var clipboard: MemoryClipboard
    var receive_updates: Bool
    var focus: FocusManager
    var status: String
    var submitted: Bool
    var cancelled: Bool

    def __init__(out self) raises:
        self.name = EditorState()
        self.clipboard = MemoryClipboard()
        self.receive_updates = False
        self.focus = FocusManager()
        self.focus.set_order([_name_id(), _updates_id(), _submit_id(), _cancel_id()])
        self.status = "Enter a display name"
        self.submitted = False
        self.cancelled = False

    def focused(self, id: FocusId) -> Bool:
        var current = self.focus.current()
        return current and current.value().equals(id)


def _validate_and_submit(mut model: FormModel) -> Bool:
    if model.name.engine.document.byte_length() == 0:
        _ = model.focus.focus(_name_id())
        model.status = "Name is required — focus returned to the first error"
        return False
    model.submitted = True
    model.status = "Submitted"
    return True


def handle_form_key(mut model: FormModel, key: KeyEvent) raises -> ControlFlow:
    """Apply one key with explicit focus, validation, and cancel semantics."""
    if not key.is_activation():
        return ControlFlow.CONTINUE
    if key.code == KeyEvent.ESCAPE:
        model.cancelled = True
        model.status = "Cancelled"
        return ControlFlow.EXIT
    if key.code == KeyEvent.TAB:
        if key.modifiers.contains(KeyEvent.SHIFT):
            model.focus.previous()
        else:
            model.focus.next()
        return ControlFlow.CONTINUE

    if model.focused(_updates_id()):
        if key.code == KeyEvent.ENTER or key.is_char(" "):
            model.receive_updates = not model.receive_updates
            model.status = (
                "Updates enabled" if model.receive_updates else "Updates disabled"
            )
        return ControlFlow.CONTINUE
    if model.focused(_submit_id()) and key.code == KeyEvent.ENTER:
        return ControlFlow.EXIT if _validate_and_submit(model) else ControlFlow.CONTINUE
    if model.focused(_cancel_id()) and key.code == KeyEvent.ENTER:
        model.cancelled = True
        model.status = "Cancelled"
        return ControlFlow.EXIT
    if not model.focused(_name_id()):
        return ControlFlow.CONTINUE

    var command: Optional[EditorCommand] = None
    if key.code == KeyEvent.BACKSPACE:
        command = EditorCommand(EditorCommandKind.DELETE_BACKWARD)
    elif key.code == KeyEvent.CHARACTER and key.modifiers == KeyEvent.NO_MODIFIERS:
        command = EditorCommand.insert(key.text)
    if command and execute_text_input_command(
        model.name, command.value(), model.clipboard
    ):
        model.status = "Editing name"
    return ControlFlow.CONTINUE


def render_form(model: FormModel, area: Rect, mut buffer: Buffer) raises:
    """Render a complete form from borrowed state."""
    var regions = Layout.vertical(
        [
            Constraint.length(3),
            Constraint.length(1),
            Constraint.length(1),
            Constraint.fill(),
            Constraint.length(1),
        ]
    ).split(area)
    if len(regions) < 5:
        return
    TextInput.with_block(
        Block.bordered(Line.from_text(" Display name ")),
        placeholder=Line.from_text("required"),
        focused=model.focused(_name_id()),
    ).render_readonly(regions[0], buffer, model.name)
    Checkbox(
        Line.from_text("Receive updates"),
        checked=model.receive_updates,
        focused=model.focused(_updates_id()),
    ).render(regions[1], buffer)

    var buttons = Layout.horizontal(
        [Constraint.length(12), Constraint.length(12), Constraint.fill()]
    ).split(regions[2])
    if len(buttons) >= 2:
        Button(Line.from_text("Submit"), focused=model.focused(_submit_id())).render(
            buttons[0], buffer
        )
        Button(Line.from_text("Cancel"), focused=model.focused(_cancel_id())).render(
            buttons[1], buffer
        )
    render_line(Line.from_text(model.status), regions[4], buffer)


struct FormApplication(Application, Copyable):
    comptime Model = FormModel
    comptime Message = KeyEvent
    comptime Effect = Bool

    def __init__(out self):
        pass

    def init(mut self) raises -> InitResult[Self.Model, Self.Effect]:
        return InitResult[Self.Model, Self.Effect].ready(FormModel())

    def update(
        mut self, mut model: Self.Model, var key: Self.Message
    ) raises -> UpdateResult[Self.Effect]:
        var control = handle_form_key(model, key)
        if control == ControlFlow.EXIT:
            return UpdateResult[Self.Effect].exit(redraw=True)
        return UpdateResult[Self.Effect].redraw_only()

    def view(self, model: Self.Model, area: Rect, mut buffer: Buffer) raises:
        render_form(model, area, buffer)

    def on_input(
        self, model: Self.Model, var event: InputEvent
    ) raises -> Optional[Self.Message]:
        if event.isa[KeyEvent]():
            return event[KeyEvent].copy()
        return None


struct FormAdapter(RuntimeAdapter):
    comptime ApplicationType = FormApplication

    def __init__(out self):
        pass

    def execute(mut self, var command: Command[Bool]) raises:
        pass

    def start(mut self, var subscription: Subscription[Bool]) raises:
        pass

    def stop(mut self, id: StringSlice) raises:
        pass

    def take_messages(mut self) raises -> MojoList[KeyEvent]:
        return []

    def close(mut self) raises:
        pass

    def close_silently(mut self):
        pass


def main() raises:
    var capabilities = detect_terminal_capabilities()
    var host = TerminalApplicationHost(
        FormAdapter(),
        FormApplication(),
        SystemClock(),
        AnsiBackend.from_terminal(capabilities=capabilities),
    )
    host.run()
