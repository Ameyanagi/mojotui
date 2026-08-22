"""Private operating-system boundary for Mojotui."""

from .posix import (
    PosixPollPairStatus,
    PosixPollStatus,
    PosixTerminalMode,
    PosixTerminalSize,
    atomic_replace_file,
    poll_readable,
    poll_readable_pair,
    read_available,
    terminal_size,
    write_all,
)
