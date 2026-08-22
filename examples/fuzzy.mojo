"""Minimal fzf-style picker with grapheme-safe match highlighting."""

from std.collections import List as MojoList, Optional

from mojotui import (
    AnsiBackend,
    Application,
    Block,
    Buffer,
    Color,
    Command,
    Constraint,
    EditorCommand,
    EditorCommandKind,
    EditorState,
    InitResult,
    InputEvent,
    KeyEvent,
    Layout,
    Line,
    List,
    ListItem,
    ListState,
    MemoryClipboard,
    Rect,
    RuntimeAdapter,
    Style,
    StylePatch,
    Subscription,
    SystemClock,
    TerminalApplicationHost,
    TextInput,
    UpdateResult,
    detect_terminal_capabilities,
    execute_text_input_command,
    render_line,
)


def _candidates() -> MojoList[String]:
    return [
        "Application runtime",
        "Buffer renderer",
        "Dashboard metrics",
        "Editor session",
        "Fuzzy finder",
        "Hello from Mojo",
        "Layout constraints",
        "Mojotui widgets",
        "Unicode graphemes",
        "Wide text: 東京",
        "北京 terminal",
        "Emoji family 👩‍👩‍👧",
        "Rocket launch 🚀",
        "Résumé viewer",
        "Zürich colors",
    ]


def _match_positions(
    candidate: StringSlice, query: StringSlice
) -> Optional[MojoList[Int]]:
    """Return case-insensitive subsequence positions as scalar indices."""
    var needle = MojoList[String]()
    var byte_offset = 0
    for scalar in query.codepoints():
        var end = byte_offset + scalar.utf8_byte_length()
        needle.append(String(query[byte=byte_offset:end]).lower())
        byte_offset = end
    var positions = MojoList[Int]()
    var next = 0
    var scalar_index = 0
    byte_offset = 0
    for scalar in candidate.codepoints():
        var end = byte_offset + scalar.utf8_byte_length()
        var folded = String(candidate[byte=byte_offset:end]).lower()
        if next < len(needle) and folded == needle[next]:
            positions.append(scalar_index)
            next += 1
        scalar_index += 1
        byte_offset = end
    if next == len(needle):
        return positions^
    return None


def _matches(query: StringSlice) -> MojoList[String]:
    var result = MojoList[String]()
    var candidates = _candidates()
    for index in range(len(candidates)):
        if _match_positions(candidates[index], query):
            result.append(candidates[index].copy())
    return result^


struct FuzzyModel(Movable):
    var input: EditorState
    var clipboard: MemoryClipboard
    var matches: MojoList[String]
    var selection: ListState
    var chosen: String

    def __init__(out self):
        self.input = EditorState()
        self.clipboard = MemoryClipboard()
        self.matches = _candidates()
        self.selection = ListState(selected=UInt(0))
        self.chosen = String()


def _query(model: FuzzyModel) -> String:
    return model.input.engine.document.to_string()


def _reset_selection(mut model: FuzzyModel):
    var query = _query(model)
    model.matches = _matches(query)
    var count = len(model.matches)
    if count > 0:
        model.selection.select(UInt(0), count)
    else:
        model.selection.select(None, 0)


def _handle_key(mut model: FuzzyModel, key: KeyEvent) raises -> Bool:
    if not key.is_activation():
        return False
    if key.code == KeyEvent.DOWN:
        model.selection.next(len(model.matches))
    elif key.code == KeyEvent.UP:
        model.selection.previous(len(model.matches))
    elif key.code == KeyEvent.ENTER:
        if model.selection.selected:
            model.chosen = model.matches[Int(model.selection.selected.value())].copy()
            return True
    elif key.code == KeyEvent.BACKSPACE:
        if execute_text_input_command(
            model.input,
            EditorCommand(EditorCommandKind.DELETE_BACKWARD),
            model.clipboard,
        ):
            _reset_selection(model)
    elif key.code == KeyEvent.CHARACTER and key.modifiers == KeyEvent.NO_MODIFIERS:
        if execute_text_input_command(
            model.input,
            EditorCommand.insert(key.text),
            model.clipboard,
        ):
            _reset_selection(model)
    return False


def _items(query: StringSlice, matches: MojoList[String]) raises -> MojoList[ListItem]:
    var items = MojoList[ListItem]()
    var patch = StylePatch(
        foreground=Color.indexed(6),
        add_modifiers=Style.BOLD,
    )
    for index in range(len(matches)):
        var positions = _match_positions(matches[index], query)
        if positions:
            items.append(
                ListItem.from_line(
                    Line.highlighted(matches[index].copy(), positions.value(), patch)
                )
            )
    return items^


struct FuzzyApplication(Application, Copyable):
    comptime Model = FuzzyModel
    comptime Message = KeyEvent
    comptime Effect = Bool

    def __init__(out self):
        pass

    def init(mut self) raises -> InitResult[Self.Model, Self.Effect]:
        return InitResult[Self.Model, Self.Effect].ready(FuzzyModel())

    def update(
        mut self, mut model: Self.Model, var key: Self.Message
    ) raises -> UpdateResult[Self.Effect]:
        if not key.is_activation():
            return UpdateResult[Self.Effect].unchanged()
        if key.code == KeyEvent.ESCAPE or (
            key.code == KeyEvent.CHARACTER
            and key.text == "c"
            and key.modifiers.contains(KeyEvent.CONTROL)
        ):
            return UpdateResult[Self.Effect].exit()
        if _handle_key(model, key):
            return UpdateResult[Self.Effect].exit()
        return UpdateResult[Self.Effect].redraw_only()

    def view(self, model: Self.Model, area: Rect, mut buffer: Buffer) raises:
        var regions = Layout.vertical(
            [Constraint.length(3), Constraint.fill(), Constraint.length(1)]
        ).split(area)
        if len(regions) < 3:
            return
        TextInput.with_block(
            Block.bordered(Line.from_text(" Filter ")), focused=True
        ).render_readonly(regions[0], buffer, model.input)
        if len(model.matches) == 0:
            render_line(Line.from_text("No matches"), regions[1], buffer)
        else:
            var list_state = model.selection.copy()
            var query = _query(model)
            List(_items(query, model.matches)).render(regions[1], buffer, list_state)
        render_line(
            Line.from_text(
                String(
                    len(model.matches),
                    " matches  ↑/↓ select  Enter choose  Esc/Ctrl-C quit",
                )
            ),
            regions[2],
            buffer,
        )

    def on_input(
        self, model: Self.Model, var event: InputEvent
    ) raises -> Optional[Self.Message]:
        if event.isa[KeyEvent]():
            var key = event[KeyEvent].copy()
            if key.is_activation():
                return key^
        return None


struct FuzzyAdapter(RuntimeAdapter):
    comptime ApplicationType = FuzzyApplication

    def __init__(out self):
        pass

    def execute(mut self, var command: Command[Self.ApplicationType.Effect]) raises:
        pass

    def start(
        mut self, var subscription: Subscription[Self.ApplicationType.Effect]
    ) raises:
        pass

    def stop(mut self, id: StringSlice) raises:
        pass

    def take_messages(mut self) raises -> MojoList[Self.ApplicationType.Message]:
        return []

    def close(mut self) raises:
        pass

    def close_silently(mut self):
        pass


def main() raises:
    var capabilities = detect_terminal_capabilities()
    var host = TerminalApplicationHost(
        FuzzyAdapter(),
        FuzzyApplication(),
        SystemClock(),
        AnsiBackend.from_terminal(capabilities=capabilities),
    )
    host.run()
    var chosen = host.application.runtime.model.chosen.copy()
    if chosen != "":
        print(chosen)
