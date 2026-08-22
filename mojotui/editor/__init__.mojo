"""Unicode-aware text editing data structures and widgets."""

from .document import (
    Document,
    DocumentRevision,
    MarkerAffinity,
    MarkerId,
    PieceSource,
    TextPosition,
)
from .history import Edit, EditorEngine
from .highlight import (
    HighlightRange,
    HighlightRequest,
    HighlightSnapshot,
    HighlightState,
)
from .clipboard import (
    Clipboard,
    MemoryClipboard,
    Osc52Clipboard,
    clipboard_round_trip,
    encode_base64,
    osc52_copy_sequence,
)
from .commands import (
    EditorCommand,
    EditorCommandKind,
    execute_editor_command,
    selected_text,
)
from .controllers import (
    ControllerActionKind,
    EditorControllerAction,
    default_editor_keymap,
    emacs_editor_keymap,
    terminal_text_input_command,
    text_input_action,
    vim_insert_keymap,
    vim_normal_keymap,
)
from .file_service import (
    FileMetadata,
    LineEnding,
    LoadedFile,
    LocalFileService,
    SaveOptions,
)
from .selection import (
    CursorMotion,
    Selection,
    SelectionSet,
    display_column,
    move_selection_left,
    move_selection_right,
    move_selection_vertical,
    move_vertical,
    next_grapheme_offset,
    offset_for_display_column,
    previous_grapheme_offset,
)
from .widget import Editor, EditorState, WrapMode
