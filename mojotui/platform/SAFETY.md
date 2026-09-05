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
presentation and session-control writes use a narrow `write(2)` loop here
because the standard library convenience API cannot report partial writes. The
loop retains no pointer, retries interrupts, rejects other errors and zero
progress, and commits terminal history or lifecycle ownership only after the
complete write succeeds. It keeps one owned byte span and advances a byte
offset; partial POSIX writes can split a UTF-8 codepoint and must never be
represented by slicing a String at that boundary.

## Atomic file replacement

Editor saves use `write_atomic_file`: `open(O_CREAT | O_EXCL | O_CLOEXEC)`
creates a caller-chosen sibling at mode 0600 filtered by the process umask.
Existing files, including dangling temporary symlinks, are never truncated.
The new descriptor is immediately transferred to a standard-library
`FileHandle`, so every exit closes it. Writes use the checked partial-write
loop. Existing destination ownership and ordinary rwx bits are applied through
`fchown` and `fchmod` on this descriptor before rename; either failure aborts.
Set-ID and sticky bits are deliberately dropped. New files retain their
initial restrictive mode. Destination symlinks and special files are rejected.

Before replacement, the destination identity, size, modification time, access
bits and ownership are compared with the preparation snapshot. A detected
change aborts. This is optimistic observation, not a filesystem lock. The
caller must control the directory and temporary path for the entire operation;
concurrent hostile directory mutation is outside the contract. Preparation or
rename failures unlink only the temporary path exclusively created by this
call. The original destination remains intact when preparation fails.

`atomic_replace_file` passes owned NUL-free path views to `rename(2)`; no pointer
survives the call. Replacement requires one filesystem. This provides atomic
visibility, not crash durability: no file or directory `fsync` is promised.
Extended ACLs, extended attributes and filesystem-specific metadata are not
copied by this mode-bit API. Callers needing those metadata contracts must use
a provider that preserves them rather than `LocalFileService`.
