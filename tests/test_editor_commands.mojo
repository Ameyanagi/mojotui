from std.testing import TestSuite, assert_equal, assert_true

from mojotui import (
    ControllerActionKind,
    EditorCommand,
    EditorCommandKind,
    EditorControllerAction,
    EditorEngine,
    KeyChord,
    KeyEvent,
    KeymapState,
    MemoryClipboard,
    Selection,
    SelectionSet,
    default_editor_keymap,
    emacs_editor_keymap,
    execute_editor_command,
    text_input_action,
    vim_insert_keymap,
    vim_normal_keymap,
)


def test_insert_delete_and_multi_cursor_commands_are_transactional() raises:
    var engine = EditorEngine("ab界cd")
    engine.selections = SelectionSet(
        [Selection.caret(1), Selection.caret(engine.document.byte_length())]
    )
    var clipboard = MemoryClipboard()
    assert_true(execute_editor_command(engine, EditorCommand.insert("X"), clipboard))
    assert_equal(engine.document.to_string(), "aXb界cdX")
    assert_true(
        execute_editor_command(
            engine,
            EditorCommand(EditorCommandKind.DELETE_BACKWARD),
            clipboard,
        )
    )
    assert_equal(engine.document.to_string(), "ab界cd")
    assert_true(
        execute_editor_command(engine, EditorCommand(EditorCommandKind.UNDO), clipboard)
    )
    assert_equal(engine.document.to_string(), "aXb界cdX")


def test_copy_cut_paste_and_select_all_use_clipboard_contract() raises:
    var engine = EditorEngine("hello")
    var clipboard = MemoryClipboard()
    _ = execute_editor_command(
        engine, EditorCommand(EditorCommandKind.SELECT_ALL), clipboard
    )
    _ = execute_editor_command(engine, EditorCommand(EditorCommandKind.COPY), clipboard)
    assert_equal(clipboard.read(), "hello")
    _ = execute_editor_command(engine, EditorCommand(EditorCommandKind.CUT), clipboard)
    assert_equal(engine.document.to_string(), "")
    _ = execute_editor_command(
        engine, EditorCommand(EditorCommandKind.PASTE), clipboard
    )
    assert_equal(engine.document.to_string(), "hello")


def test_default_and_emacs_keymaps_produce_semantic_actions() raises:
    var defaults = default_editor_keymap()
    var default_state = KeymapState[EditorControllerAction]()
    var left = defaults.resolve(default_state, KeyChord(KeyEvent.LEFT), "editor", 0)
    assert_equal(left.actions[0].command.kind, EditorCommandKind.MOVE_LEFT)

    var emacs = emacs_editor_keymap()
    var emacs_state = KeymapState[EditorControllerAction]()
    var forward = emacs.resolve(
        emacs_state,
        KeyChord.character("f", KeyEvent.CONTROL),
        "emacs",
        0,
    )
    assert_equal(forward.actions[0].command.kind, EditorCommandKind.MOVE_RIGHT)


def test_vim_keymaps_include_modes_and_multi_key_motion() raises:
    var normal = vim_normal_keymap()
    var state = KeymapState[EditorControllerAction]()
    var pending = normal.resolve(state, KeyChord.character("g"), "vim-normal", 0)
    assert_true(pending.pending)
    var matched = normal.resolve(state, KeyChord.character("g"), "vim-normal", 1)
    assert_equal(matched.actions[0].command.kind, EditorCommandKind.DOCUMENT_START)

    var insert = vim_insert_keymap()
    var insert_state = KeymapState[EditorControllerAction]()
    var escape = insert.resolve(
        insert_state, KeyChord(KeyEvent.ESCAPE), "vim-insert", 0
    )
    assert_equal(escape.actions[0].kind, ControllerActionKind.ENTER_NORMAL)


def test_unbound_text_input_becomes_insert_action() raises:
    var action = text_input_action(KeyEvent.character("界"))
    assert_true(action)
    assert_equal(action.value().command.kind, EditorCommandKind.INSERT)
    assert_equal(action.value().command.text, "界")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
