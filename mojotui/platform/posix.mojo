"""Audited POSIX boundary for macOS and Linux terminals.

No pointer or platform ABI type from this module is exposed publicly. See
`SAFETY.md` in this package for the invariants behind each FFI call.
"""

from std.collections import Array, List
from std.ffi import c_int, c_short, c_uint, c_ulong, external_call, get_errno
from std.io import FileDescriptor, FileHandle
from std.io.file import O_CLOEXEC, O_CREAT, O_WRONLY
from std.pathlib import Path
from std.os.path import islink
from std.stat import S_ISREG
from std.sys import CompilationTarget, is_little_endian


comptime _TERMIOS_WORDS = 32
comptime _TCSANOW = c_int(0)
comptime _POLLIN = c_short(0x0001)
comptime _POLLERR = c_short(0x0008)
comptime _POLLHUP = c_short(0x0010)
comptime _POLLNVAL = c_short(0x0020)
comptime _EINTR = c_int(4)
comptime _ENOTTY = 25
comptime _nfds_t = c_ulong if CompilationTarget.is_linux() else c_uint
comptime _TIOCGWINSZ = (
    c_ulong(0x5413) if CompilationTarget.is_linux() else c_ulong(0x40087468)
)


struct PosixTerminalSize(Copyable):
    """A terminal size returned as ordinary owned integers."""

    var columns: Int
    var rows: Int

    def __init__(out self, columns: Int = 0, rows: Int = 0):
        self.columns = max(columns, 0)
        self.rows = max(rows, 0)

    def equals(self, other: Self) -> Bool:
        return self.columns == other.columns and self.rows == other.rows


struct PosixPollStatus(Copyable):
    """Owned result of polling one descriptor."""

    var readable: Bool
    var timed_out: Bool
    var interrupted: Bool
    var hangup: Bool
    var failed: Bool

    def __init__(
        out self,
        readable: Bool = False,
        timed_out: Bool = False,
        interrupted: Bool = False,
        hangup: Bool = False,
        failed: Bool = False,
    ):
        self.readable = readable
        self.timed_out = timed_out
        self.interrupted = interrupted
        self.hangup = hangup
        self.failed = failed


struct PosixPollPairStatus(Copyable):
    """Owned readiness for an input descriptor and an optional wakeup."""

    var first: PosixPollStatus
    var second: PosixPollStatus

    def __init__(
        out self,
        first: PosixPollStatus = PosixPollStatus(),
        second: PosixPollStatus = PosixPollStatus(),
    ):
        self.first = first.copy()
        self.second = second.copy()


struct PosixTerminalMode(Movable):
    """RAII owner of one saved POSIX terminal configuration.

    Construction refuses an already-raw descriptor. This prevents destructive
    nested Mojotui restores on the same input TTY. It is an overlap guard, not
    a process-global or cross-process device lease.
    """

    var descriptor: Int
    var saved: Array[UInt64, _TERMIOS_WORDS]
    var active: Bool

    def __init__(out self, descriptor: Int) raises:
        self.descriptor = descriptor
        self.saved = Array[UInt64, _TERMIOS_WORDS](fill=0)
        self.active = False

        if not FileDescriptor(descriptor).isatty():
            raise Error(
                String(
                    "input descriptor ",
                    descriptor,
                    (
                        " is not an interactive terminal; run from a TTY, or drive the"
                        " application with HeadlessBackend for non-interactive use"
                    ),
                )
            )

        # SAFETY: `saved` is aligned, initialized, live for the call, and larger
        # than `struct termios` on every supported target. libc writes only its
        # own structure size.
        var status = external_call["tcgetattr", c_int](
            c_int(descriptor), Pointer(to=self.saved[0])
        )
        if status != 0:
            raise Error("tcgetattr failed with errno ", String(get_errno().value))

        var raw = self.saved.copy()
        # SAFETY: `raw` has the same valid storage invariant as `saved` and is
        # used only during this initializer.
        external_call["cfmakeraw", NoneType](Pointer(to=raw[0]))
        var already_raw = True
        for index in range(_TERMIOS_WORDS):
            if raw[index] != self.saved[index]:
                already_raw = False
                break
        if already_raw:
            raise Error(
                String(
                    "input descriptor ",
                    descriptor,
                    " is already in raw mode; another terminal session may own it",
                )
            )
        # SAFETY: `raw` contains a configuration produced by libc from the
        # successfully captured configuration for this same descriptor.
        status = external_call["tcsetattr", c_int](
            c_int(descriptor), _TCSANOW, Pointer(to=raw[0])
        )
        if status != 0:
            raise Error("tcsetattr failed with errno ", String(get_errno().value))
        self.active = True

    def restore(mut self) raises:
        """Restore the captured terminal state exactly once."""
        if not self.active:
            return
        # SAFETY: `saved` still owns the initialized configuration captured by
        # `tcgetattr`, and no pointer survives this call.
        var status = external_call["tcsetattr", c_int](
            c_int(self.descriptor), _TCSANOW, Pointer(to=self.saved[0])
        )
        if status != 0:
            raise Error(
                "terminal restoration failed with errno ",
                String(get_errno().value),
            )
        self.active = False

    def restore_silently(mut self):
        """Best-effort restoration for non-raising destruction paths."""
        if not self.active:
            return
        # SAFETY: identical to `restore`; destruction cannot surface errors.
        var status = external_call["tcsetattr", c_int](
            c_int(self.descriptor), _TCSANOW, Pointer(to=self.saved[0])
        )
        if status == 0:
            self.active = False

    def __deinit__(deinit self):
        if self.active:
            # SAFETY: identical to `restore`; the storage remains live through
            # the end of this destructor and the return value cannot be raised.
            _ = external_call["tcsetattr", c_int](
                c_int(self.descriptor), _TCSANOW, Pointer(to=self.saved[0])
            )


def terminal_size(descriptor: Int) raises -> PosixTerminalSize:
    """Query a terminal size without exposing `struct winsize`."""
    var values = Array[UInt16, 4](fill=0)
    # SAFETY: Linux and macOS define `winsize` as four consecutive unsigned
    # shorts. `values` is aligned and live, and ioctl receives its native
    # platform request constant.
    var status = external_call["ioctl", c_int, num_fixed_args=2](
        c_int(descriptor), _TIOCGWINSZ, Pointer(to=values[0])
    )
    if status != 0:
        var error_number = get_errno().value
        if error_number == _ENOTTY:
            raise Error(
                String(
                    "terminal-size query failed: descriptor ",
                    descriptor,
                    (
                        " is not an interactive terminal (ENOTTY); run from a TTY, or"
                        " use HeadlessBackend for non-interactive output"
                    ),
                )
            )
        raise Error(
            String(
                "terminal-size query failed for descriptor ",
                descriptor,
                " with errno ",
                error_number,
            )
        )
    return PosixTerminalSize(Int(values[1]), Int(values[0]))


def _poll_status(events_word: UInt32) -> PosixPollStatus:
    var events = c_short(Int(events_word >> 16))
    return PosixPollStatus(
        readable=(events & _POLLIN) != 0,
        hangup=(events & _POLLHUP) != 0,
        failed=(events & (_POLLERR | _POLLNVAL)) != 0,
    )


def poll_readable_pair(
    first_descriptor: Int,
    second_descriptor: Int,
    timeout_ms: Int,
) raises -> PosixPollPairStatus:
    """Wait for input plus an optional second descriptor in one libc call."""
    comptime assert (
        is_little_endian()
    ), "POSIX poll packing requires a little-endian target"
    # `struct pollfd` is eight bytes on both targets: one 32-bit descriptor,
    # followed by the requested and returned 16-bit event masks. Packing the
    # two shorts into one word avoids relying on Mojo struct field layout.
    var items: Array[UInt32, 4] = [
        UInt32(first_descriptor),
        UInt32(Int(_POLLIN)),
        UInt32(max(second_descriptor, 0)),
        UInt32(Int(_POLLIN)),
    ]
    var descriptor_count = 2 if second_descriptor >= 0 else 1
    var timeout = max(-1, min(timeout_ms, Int(c_int.MAX)))
    # SAFETY: each two-word prefix in `items` is the exact eight-byte
    # little-endian representation of one POSIX `struct pollfd`. The initialized
    # array is live and uniquely mutable, and `descriptor_count` limits libc to
    # either its first one or first two entries.
    var status = external_call["poll", c_int](
        Pointer(to=items[0]),
        _nfds_t(from_int=descriptor_count),
        c_int(timeout),
    )
    if status < 0:
        if get_errno().value == _EINTR:
            return PosixPollPairStatus(
                PosixPollStatus(interrupted=True),
                PosixPollStatus(interrupted=True),
            )
        raise Error("poll failed with errno ", String(get_errno().value))
    if status == 0:
        return PosixPollPairStatus(
            PosixPollStatus(timed_out=True),
            PosixPollStatus(timed_out=True),
        )
    return PosixPollPairStatus(
        _poll_status(items[1]),
        _poll_status(items[3]) if second_descriptor >= 0 else PosixPollStatus(),
    )


def poll_readable(descriptor: Int, timeout_ms: Int) raises -> PosixPollStatus:
    """Wait for one descriptor, with a bounded millisecond timeout."""
    var result = poll_readable_pair(descriptor, -1, timeout_ms)
    return result.first.copy()


def read_available(descriptor: Int, limit: Int = 4096) raises -> List[UInt8]:
    """Read one ready descriptor through Mojo's safe `FileDescriptor` API."""
    var capacity = max(1, min(limit, 65536))
    var storage = List[UInt8](length=capacity, fill=0)
    var fd = FileDescriptor(descriptor)
    var count = fd.read_bytes(storage)
    var result = List[UInt8](capacity=count)
    for index in range(count):
        result.append(storage[index])
    return result^


def write_all(descriptor: Int, content: StringSlice) raises:
    """Write every byte or report the first non-interrupt transport error."""
    var payload = String(content)
    var bytes = payload.as_bytes()
    var offset = 0
    while offset < payload.byte_length():
        # SAFETY: `payload` owns these bytes without mutation for the loop.
        # `offset` advances by checked positive write counts within the span;
        # libc reads at most the remaining count and retains no pointer. A
        # partial write may end inside UTF-8, so progress is byte-granular.
        var written = external_call["write", Int](
            descriptor,
            bytes.unsafe_ptr().unsafe_offset(offset),
            payload.byte_length() - offset,
        )
        if written < 0:
            if get_errno().value == _EINTR:
                continue
            raise Error(
                "terminal write failed for descriptor ",
                String(descriptor),
                " with errno ",
                String(get_errno().value),
            )
        if written == 0:
            raise Error(
                "terminal write made no progress for descriptor ",
                String(descriptor),
            )
        offset += written


def atomic_replace_file(var source: String, var destination: String) raises:
    """Atomically replace a POSIX path with a prepared same-filesystem file."""
    if "\0" in source or "\0" in destination:
        raise Error("filesystem path contains a null byte")
    # SAFETY: both owned strings remain alive for the complete libc call and
    # provide null-terminated read-only C views. POSIX `rename` retains no
    # pointer and atomically replaces `destination` on the same filesystem.
    var status = external_call["rename", c_int](
        source.as_c_string_slice(), destination.as_c_string_slice()
    )
    if status != 0:
        raise Error("atomic file replace failed with errno ", String(get_errno().value))


def write_atomic_file(
    var temporary_path: String, var destination: String, content: StringSlice
) raises:
    """Prepare a private, exclusive sibling and preserve POSIX access bits.

    Callers must control the containing directory. Extended ACLs and other
    filesystem-specific metadata are outside this mode-bit contract.
    """
    if "\0" in temporary_path or "\0" in destination:
        raise Error("filesystem path contains a null byte")
    if islink(destination):
        raise Error(
            String(
                "atomic save destination '",
                destination,
                "' is a symlink; choose its regular-file target explicitly",
            )
        )
    var existing = Path(destination).exists()
    var device = 0
    var inode = 0
    var size = 0
    var modified_ns = 0
    var mode = 0o600
    var owner = c_uint.MAX
    var group = c_uint.MAX
    if existing:
        var observed = Path(destination).lstat()
        if not S_ISREG(observed.st_mode):
            raise Error(
                String(
                    "atomic save destination '",
                    destination,
                    (
                        "' must be a regular file; choose a file path instead of a"
                        " directory, symlink, or special file"
                    ),
                )
            )
        mode = Int(observed.st_mode) & 0o777
        owner = c_uint(observed.st_uid)
        group = c_uint(observed.st_gid)
        device = observed.st_dev
        inode = observed.st_ino
        size = observed.st_size
        modified_ns = observed.st_mtimespec.as_nanoseconds()
    # O_EXCL with O_CREAT rejects both an existing file and a symlink, including
    # a dangling symlink. New content is never written to an attacker-chosen fd.
    comptime exclusive = 128 if CompilationTarget.is_linux() else 2048
    # SAFETY: the owned string is NUL-free and live for open(2), flags are the
    # native platform constants, and the variadic mode is promoted to c_int.
    var descriptor = external_call["open", c_int, num_fixed_args=2](
        temporary_path.as_c_string_slice(),
        c_int(O_WRONLY | O_CREAT | O_CLOEXEC | exclusive),
        c_int(0o600),
    )
    if descriptor < 0:
        raise Error(
            String(
                "atomic save temporary path '",
                temporary_path,
                "' cannot be exclusively created (errno ",
                get_errno().value,
                "); choose an unused writable sibling path",
            )
        )
    var file = FileHandle()
    # SAFETY: transfer the freshly opened fd to the stdlib RAII owner; no other
    # code owns or closes this descriptor. It is closed on every exit path.
    file.handle = Int(descriptor)
    try:
        write_all(Int(descriptor), content)
        if existing:
            # SAFETY: descriptor is a live owned file and uid/gid came from
            # successful lstat. Failure aborts before replacing the destination.
            if external_call["fchown", c_int](descriptor, owner, group) != 0:
                raise Error(
                    String(
                        "atomic save destination '",
                        destination,
                        "' ownership cannot be preserved (uid ",
                        owner,
                        ", gid ",
                        group,
                        ", errno ",
                        get_errno().value,
                        "); save to a file whose ownership you can retain",
                    )
                )
            # SAFETY: only ordinary rwx bits from the observed destination are
            # applied to our owned fd, after writing/chown can clear mode bits.
            if external_call["fchmod", c_int](descriptor, c_uint(mode)) != 0:
                raise Error(
                    String(
                        "atomic save destination '",
                        destination,
                        "' permission bits ",
                        mode,
                        " cannot be preserved (errno ",
                        get_errno().value,
                        "); check the filesystem's permission support",
                    )
                )
        file.close()
        if existing:
            var current = Path(destination).lstat()
            if (
                current.st_dev != device
                or current.st_ino != inode
                or current.st_size != size
                or current.st_mtimespec.as_nanoseconds() != modified_ns
                or Int(current.st_mode) & 0o777 != mode
                or c_uint(current.st_uid) != owner
                or c_uint(current.st_gid) != group
            ):
                raise Error(
                    String(
                        "atomic save destination '",
                        destination,
                        (
                            "' changed while preparing replacement; reload before"
                            " retrying the save"
                        ),
                    )
                )
        elif Path(destination).exists() or islink(destination):
            raise Error(
                String(
                    "atomic save destination '",
                    destination,
                    (
                        "' appeared while preparing replacement; reload before retrying"
                        " the save"
                    ),
                )
            )
        atomic_replace_file(temporary_path.copy(), destination.copy())
    except error:
        # SAFETY: unlink only the temporary path successfully created here.
        # The directory is caller-controlled and no pointer survives the call.
        _ = external_call["unlink", c_int](temporary_path.as_c_string_slice())
        raise error^
