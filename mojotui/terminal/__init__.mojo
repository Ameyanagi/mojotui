"""Terminal backend contracts and safe implementations."""

from .ansi import (
    encode_ansi_diff,
    encode_ansi_inline_diff,
    inline_clear_sequence,
    inline_reserve_sequence,
)
from .backend import AnsiBackend, Backend, HeadlessBackend, InlineBackend, Terminal
from .session import (
    SessionOptions,
    TerminalSession,
    session_enter_sequence,
    session_leave_sequence,
)
