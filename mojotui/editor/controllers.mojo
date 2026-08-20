"""Default, Emacs, and Vim keymap builders for editor semantic commands."""

from std.collections import Optional

from ..app.keymap import KeyChord, Keymap
from ..event.input import KeyEvent
from .commands import EditorCommand, EditorCommandKind


struct ControllerActionKind(Copyable, Equatable, ImplicitlyCopyable):
    """Nominal editor-controller transition or edit action."""

    comptime EDIT = ControllerActionKind(0, _validated=True)
    comptime ENTER_INSERT = ControllerActionKind(1, _validated=True)
    comptime ENTER_NORMAL = ControllerActionKind(2, _validated=True)

    var _value: Int

    def __init__(out self, value: Int, *, _validated: Bool):
        self._value = value

    def __init__(out self, value: Int) raises:
        if value < 0 or value > 2:
            raise Error("invalid editor controller action kind")
        self._value = value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value


struct EditorControllerAction(Copyable):
    var kind: ControllerActionKind
    var command: Optional[EditorCommand]

    def __init__(
        out self,
        kind: ControllerActionKind,
        command: Optional[EditorCommand] = None,
    ):
        self.kind = kind
        self.command = command.copy()

    @staticmethod
    def edit(command: EditorCommand) -> Self:
        return Self(ControllerActionKind.EDIT, command.copy())


def _bind_common(
    mut keymap: Keymap[EditorControllerAction], var context: String
) raises:
    keymap.bind_key(
        context.copy(),
        KeyChord(KeyEvent.LEFT),
        EditorControllerAction.edit(EditorCommand.motion(EditorCommandKind.MOVE_LEFT)),
    )
    keymap.bind_key(
        context.copy(),
        KeyChord(KeyEvent.RIGHT),
        EditorControllerAction.edit(EditorCommand.motion(EditorCommandKind.MOVE_RIGHT)),
    )
    keymap.bind_key(
        context.copy(),
        KeyChord(KeyEvent.UP),
        EditorControllerAction.edit(EditorCommand.motion(EditorCommandKind.MOVE_UP)),
    )
    keymap.bind_key(
        context.copy(),
        KeyChord(KeyEvent.DOWN),
        EditorControllerAction.edit(EditorCommand.motion(EditorCommandKind.MOVE_DOWN)),
    )
    keymap.bind_key(
        context.copy(),
        KeyChord(KeyEvent.LEFT, modifiers=KeyEvent.SHIFT),
        EditorControllerAction.edit(
            EditorCommand.motion(EditorCommandKind.MOVE_LEFT, extend=True)
        ),
    )
    keymap.bind_key(
        context.copy(),
        KeyChord(KeyEvent.RIGHT, modifiers=KeyEvent.SHIFT),
        EditorControllerAction.edit(
            EditorCommand.motion(EditorCommandKind.MOVE_RIGHT, extend=True)
        ),
    )
    keymap.bind_key(
        context.copy(),
        KeyChord(KeyEvent.BACKSPACE),
        EditorControllerAction.edit(EditorCommand(EditorCommandKind.DELETE_BACKWARD)),
    )
    keymap.bind_key(
        context.copy(),
        KeyChord(KeyEvent.DELETE),
        EditorControllerAction.edit(EditorCommand(EditorCommandKind.DELETE_FORWARD)),
    )
    keymap.bind_key(
        context.copy(),
        KeyChord(KeyEvent.ENTER),
        EditorControllerAction.edit(EditorCommand(EditorCommandKind.NEWLINE)),
    )
    keymap.bind_key(
        context.copy(),
        KeyChord(KeyEvent.HOME),
        EditorControllerAction.edit(EditorCommand(EditorCommandKind.LINE_START)),
    )
    keymap.bind_key(
        context.copy(),
        KeyChord(KeyEvent.END),
        EditorControllerAction.edit(EditorCommand(EditorCommandKind.LINE_END)),
    )


def _control(var text: String) -> KeyChord:
    return KeyChord.character(text^, KeyEvent.CONTROL)


def default_editor_keymap() raises -> Keymap[EditorControllerAction]:
    var keymap = Keymap[EditorControllerAction]()
    _bind_common(keymap, "editor")
    keymap.bind_key(
        "editor",
        _control("a"),
        EditorControllerAction.edit(EditorCommand(EditorCommandKind.SELECT_ALL)),
    )
    keymap.bind_key(
        "editor",
        _control("c"),
        EditorControllerAction.edit(EditorCommand(EditorCommandKind.COPY)),
    )
    keymap.bind_key(
        "editor",
        _control("x"),
        EditorControllerAction.edit(EditorCommand(EditorCommandKind.CUT)),
    )
    keymap.bind_key(
        "editor",
        _control("v"),
        EditorControllerAction.edit(EditorCommand(EditorCommandKind.PASTE)),
    )
    keymap.bind_key(
        "editor",
        _control("z"),
        EditorControllerAction.edit(EditorCommand(EditorCommandKind.UNDO)),
    )
    keymap.bind_key(
        "editor",
        _control("y"),
        EditorControllerAction.edit(EditorCommand(EditorCommandKind.REDO)),
    )
    return keymap^


def emacs_editor_keymap() raises -> Keymap[EditorControllerAction]:
    var keymap = Keymap[EditorControllerAction]()
    _bind_common(keymap, "emacs")
    keymap.bind_key(
        "emacs",
        _control("b"),
        EditorControllerAction.edit(EditorCommand.motion(EditorCommandKind.MOVE_LEFT)),
    )
    keymap.bind_key(
        "emacs",
        _control("f"),
        EditorControllerAction.edit(EditorCommand.motion(EditorCommandKind.MOVE_RIGHT)),
    )
    keymap.bind_key(
        "emacs",
        _control("p"),
        EditorControllerAction.edit(EditorCommand.motion(EditorCommandKind.MOVE_UP)),
    )
    keymap.bind_key(
        "emacs",
        _control("n"),
        EditorControllerAction.edit(EditorCommand.motion(EditorCommandKind.MOVE_DOWN)),
    )
    keymap.bind_key(
        "emacs",
        _control("d"),
        EditorControllerAction.edit(EditorCommand(EditorCommandKind.DELETE_FORWARD)),
    )
    return keymap^


def vim_normal_keymap() raises -> Keymap[EditorControllerAction]:
    var keymap = Keymap[EditorControllerAction]()
    keymap.bind_key(
        "vim-normal",
        KeyChord.character("h"),
        EditorControllerAction.edit(EditorCommand.motion(EditorCommandKind.MOVE_LEFT)),
    )
    keymap.bind_key(
        "vim-normal",
        KeyChord.character("j"),
        EditorControllerAction.edit(EditorCommand.motion(EditorCommandKind.MOVE_DOWN)),
    )
    keymap.bind_key(
        "vim-normal",
        KeyChord.character("k"),
        EditorControllerAction.edit(EditorCommand.motion(EditorCommandKind.MOVE_UP)),
    )
    keymap.bind_key(
        "vim-normal",
        KeyChord.character("l"),
        EditorControllerAction.edit(EditorCommand.motion(EditorCommandKind.MOVE_RIGHT)),
    )
    keymap.bind_key(
        "vim-normal",
        KeyChord.character("x"),
        EditorControllerAction.edit(EditorCommand(EditorCommandKind.DELETE_FORWARD)),
    )
    keymap.bind_key(
        "vim-normal",
        KeyChord.character("u"),
        EditorControllerAction.edit(EditorCommand(EditorCommandKind.UNDO)),
    )
    keymap.bind_key(
        "vim-normal",
        KeyChord.character("i"),
        EditorControllerAction(ControllerActionKind.ENTER_INSERT),
    )
    keymap.bind(
        "vim-normal",
        [KeyChord.character("g"), KeyChord.character("g")],
        EditorControllerAction.edit(EditorCommand(EditorCommandKind.DOCUMENT_START)),
    )
    keymap.bind_key(
        "vim-normal",
        KeyChord.character("G"),
        EditorControllerAction.edit(EditorCommand(EditorCommandKind.DOCUMENT_END)),
    )
    keymap.bind_key(
        "vim-normal",
        _control("r"),
        EditorControllerAction.edit(EditorCommand(EditorCommandKind.REDO)),
    )
    return keymap^


def vim_insert_keymap() raises -> Keymap[EditorControllerAction]:
    var keymap = Keymap[EditorControllerAction]()
    _bind_common(keymap, "vim-insert")
    keymap.bind_key(
        "vim-insert",
        KeyChord(KeyEvent.ESCAPE),
        EditorControllerAction(ControllerActionKind.ENTER_NORMAL),
    )
    return keymap^


def text_input_action(
    key: KeyEvent, accepts_text: Bool = True
) -> Optional[EditorControllerAction]:
    """Translate unmodified character input after keymap resolution misses."""
    if (
        accepts_text
        and key.code == KeyEvent.CHARACTER
        and key.modifiers == KeyEvent.NO_MODIFIERS
        and key.text != ""
    ):
        return EditorControllerAction.edit(EditorCommand.insert(key.text.copy()))
    return None
