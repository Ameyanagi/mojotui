# POSIX safety boundary

Mojotui's core, text, widgets, application, and editor layers do not call FFI
or handle raw pointers. `posix.mojo` is the only current exception.

The boundary supports macOS and Linux and owns no borrowed pointer after a libc
call returns. Public callers exchange file-descriptor integers, owned byte
lists, booleans, and terminal dimensions.

## Terminal state

`PosixTerminalMode` uses 256 bytes of initialized, eight-byte-aligned storage.
This is deliberately larger than `struct termios` on both supported platforms.
The layout is never interpreted by Mojo: `tcgetattr` initializes the meaningful
prefix, `cfmakeraw` modifies a copy, and `tcsetattr` consumes either the copy or
the saved original. The storage and its tracked pointer remain live for every
call. A successful raw-mode transition sets the restoration flag only after
`tcsetattr` succeeds.

The explicit `restore()` path reports errors. Destruction performs the same
operation best-effort because Mojo destructors cannot propagate a restoration
failure. `SIGKILL` cannot run cleanup and is outside the guarantee.

## Polling

Each `pollfd` is represented as two `UInt32` words: the descriptor, followed by
the requested and returned 16-bit masks. The initialized four-word array holds
the terminal input descriptor and an optional wakeup descriptor; the count
passed to libc selects one or both entries. All supported macOS/Linux targets
are little-endian, and a compile-time assertion rejects any future big-endian
target. This exact eight-byte-per-entry representation avoids relying on Mojo
struct field layout. The `nfds_t` argument is selected as `unsigned int` on
macOS and `unsigned long` on Linux. The storage is uniquely mutable and live
throughout `poll`.

## Terminal size

Both supported systems define `struct winsize` as four consecutive unsigned
shorts. Mojo passes an initialized four-element `UInt16` array with the native
`TIOCGWINSZ` request number and reads rows and columns only after success.

## Ordinary I/O

Byte reads use the standard library's `FileDescriptor.read_bytes()`. Terminal
session control writes use a narrow `write(2)` loop here because the standard
library convenience API cannot report partial writes. The loop retains no
pointer, rejects errors and zero progress, and lets session construction roll
back raw mode after an enter-sequence failure.

## Atomic file replacement

Editor saves prepare a complete sibling temporary file through Mojo's standard
library. The POSIX boundary then passes two owned, null-terminated string views
to `rename(2)`. Both strings remain live for the call, embedded nulls are
rejected, and libc retains neither pointer. Atomic replacement requires the
temporary file and destination to be on the same filesystem; failures leave
the prepared temporary file available for recovery.
