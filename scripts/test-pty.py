#!/usr/bin/env python3
"""Exercise terminal lifecycle guarantees against a real pseudo-terminal."""

from __future__ import annotations

import fcntl
import os
import pty
import select
import struct
import subprocess
import sys
import termios
import time
from pathlib import Path


READ_TIMEOUT_SECONDS = 5.0


def comparable_attributes(attributes: list[object]) -> list[object]:
    """Ignore kernel-owned transient flags while comparing user configuration."""
    result = list(attributes)
    result[3] = int(result[3]) & ~int(getattr(termios, "PENDIN", 0))
    result[6] = list(result[6])
    return result


def read_until(master: int, process: subprocess.Popen[bytes], marker: bytes) -> bytes:
    output = bytearray()
    deadline = time.monotonic() + READ_TIMEOUT_SECONDS
    while marker not in output and time.monotonic() < deadline:
        readable, _, _ = select.select([master], [], [], 0.1)
        if readable:
            try:
                output.extend(os.read(master, 4096))
            except OSError:
                break
        if process.poll() is not None and not readable:
            break
    if marker not in output:
        raise AssertionError(
            f"child did not emit {marker!r}; exit={process.poll()}, output={output!r}"
        )
    return bytes(output)


def run_case(
    binary: Path,
    mode: str,
    *,
    send_control_c: bool = False,
    resize: bool = False,
) -> None:
    master, slave = pty.openpty()
    try:
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0))
        original = termios.tcgetattr(slave)
        process = subprocess.Popen(
            [str(binary), mode],
            stdin=slave,
            stdout=slave,
            stderr=slave,
            close_fds=True,
        )
        output = read_until(master, process, b"READY")

        if process.poll() is None:
            raw = termios.tcgetattr(slave)
            if raw[3] & (termios.ICANON | termios.ECHO):
                raise AssertionError(f"{mode}: terminal did not enter raw mode")

        if resize:
            fcntl.ioctl(
                slave,
                termios.TIOCSWINSZ,
                struct.pack("HHHH", 40, 100, 0, 0),
            )
            read_until(master, process, b"RESIZED")
        elif send_control_c:
            os.write(master, b"\x03")
        else:
            os.write(master, b"x")

        expected_success = mode != "error"
        deadline = time.monotonic() + READ_TIMEOUT_SECONDS
        while process.poll() is None and time.monotonic() < deadline:
            readable, _, _ = select.select([master], [], [], 0.1)
            if readable:
                try:
                    output += os.read(master, 4096)
                except OSError:
                    break
        if process.poll() is None:
            process.kill()
            process.wait()
            raise AssertionError(f"{mode}: child timed out; output={output!r}") from None
        exit_code = process.returncode

        restored = termios.tcgetattr(slave)
        if comparable_attributes(restored) != comparable_attributes(original):
            raise AssertionError(
                f"{mode}: terminal attributes were not restored\n"
                f"original={original!r}\nrestored={restored!r}"
            )
        if expected_success and exit_code != 0:
            raise AssertionError(f"{mode}: expected success, got exit {exit_code}")
        if not expected_success and exit_code == 0:
            raise AssertionError(f"{mode}: expected intentional failure")
    finally:
        os.close(master)
        os.close(slave)


def run_split_descriptor_case(binary: Path) -> None:
    input_master, input_slave = pty.openpty()
    output_master, output_slave = pty.openpty()
    try:
        fcntl.ioctl(
            input_slave,
            termios.TIOCSWINSZ,
            struct.pack("HHHH", 24, 80, 0, 0),
        )
        fcntl.ioctl(
            output_slave,
            termios.TIOCSWINSZ,
            struct.pack("HHHH", 40, 100, 0, 0),
        )
        original_input = termios.tcgetattr(input_slave)
        process = subprocess.Popen(
            [str(binary), "split-descriptors"],
            stdin=input_slave,
            stdout=output_slave,
            stderr=output_slave,
            close_fds=True,
        )
        output = read_until(output_master, process, b"READY")
        raw_input = termios.tcgetattr(input_slave)
        if raw_input[3] & (termios.ICANON | termios.ECHO):
            raise AssertionError("split-descriptors: input did not enter raw mode")

        fcntl.ioctl(
            output_slave,
            termios.TIOCSWINSZ,
            struct.pack("HHHH", 50, 120, 0, 0),
        )
        output += read_until(output_master, process, b"RESIZED")
        process.wait(timeout=READ_TIMEOUT_SECONDS)
        if process.returncode != 0:
            raise AssertionError(
                "split-descriptors: expected success, "
                f"got exit {process.returncode}; output={output!r}"
            )

        restored_input = termios.tcgetattr(input_slave)
        if comparable_attributes(restored_input) != comparable_attributes(
            original_input
        ):
            raise AssertionError(
                "split-descriptors: input attributes were not restored"
            )
    finally:
        os.close(input_master)
        os.close(input_slave)
        os.close(output_master)
        os.close(output_slave)


def run_editor_case(binary: Path) -> None:
    """Start the real editor host, quit through input, and verify restoration."""
    master, slave = pty.openpty()
    try:
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0))
        original = termios.tcgetattr(slave)
        process = subprocess.Popen(
            [str(binary)],
            stdin=slave,
            stdout=slave,
            stderr=slave,
            close_fds=True,
        )
        output = read_until(master, process, b"Ctrl-Q")
        raw = termios.tcgetattr(slave)
        if raw[3] & (termios.ICANON | termios.ECHO):
            raise AssertionError("editor: terminal did not enter raw mode")

        os.write(master, b"\x11")
        deadline = time.monotonic() + READ_TIMEOUT_SECONDS
        while process.poll() is None and time.monotonic() < deadline:
            readable, _, _ = select.select([master], [], [], 0.1)
            if readable:
                try:
                    output += os.read(master, 4096)
                except OSError:
                    break
        if process.poll() is None:
            process.kill()
            process.wait()
            raise AssertionError(f"editor: child timed out; output={output!r}")
        if process.returncode != 0:
            raise AssertionError(
                f"editor: expected success, got exit {process.returncode}"
            )
        if b"\x1b[?1049l" not in output:
            raise AssertionError("editor: alternate screen was not restored")
        restored = termios.tcgetattr(slave)
        if comparable_attributes(restored) != comparable_attributes(original):
            raise AssertionError("editor: terminal attributes were not restored")
    finally:
        os.close(master)
        os.close(slave)


def run_virtual_list_case(binary: Path) -> None:
    """Jump through a real PTY and verify a lazy distant row is presented."""
    master, slave = pty.openpty()
    try:
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0))
        original = termios.tcgetattr(slave)
        process = subprocess.Popen(
            [str(binary)],
            stdin=slave,
            stdout=slave,
            stderr=slave,
            close_fds=True,
        )
        output = read_until(master, process, b"formatted")
        raw = termios.tcgetattr(slave)
        if raw[3] & (termios.ICANON | termios.ECHO):
            raise AssertionError("virtual-list: terminal did not enter raw mode")

        os.write(master, b"\x1b[F")
        # The first digit is independently styled by Line.highlighted; the
        # remaining suffix is a stable marker for the selected final row.
        output += read_until(master, process, b"9999")
        os.write(master, b"q")
        process.wait(timeout=READ_TIMEOUT_SECONDS)
        if process.returncode != 0:
            raise AssertionError(
                "virtual-list: expected success, "
                f"got exit {process.returncode}; output={output!r}"
            )
        if b"\x1b[?1049l" not in output:
            readable, _, _ = select.select([master], [], [], 0.2)
            if readable:
                try:
                    output += os.read(master, 4096)
                except OSError:
                    pass
        if b"\x1b[?1049l" not in output:
            raise AssertionError("virtual-list: alternate screen was not restored")
        restored = termios.tcgetattr(slave)
        if comparable_attributes(restored) != comparable_attributes(original):
            raise AssertionError("virtual-list: terminal attributes were not restored")
    finally:
        os.close(master)
        os.close(slave)


def main() -> int:
    if len(sys.argv) not in (2, 3, 4):
        print(
            "usage: test-pty.py PATH_TO_SESSION_PROBE "
            "[PATH_TO_EDITOR [PATH_TO_VIRTUAL_LIST]]",
            file=sys.stderr,
        )
        return 2
    binary = Path(sys.argv[1]).resolve()
    for mode in ("normal", "implicit", "error", "host"):
        run_case(binary, mode)
    run_case(binary, "control-c", send_control_c=True)
    run_case(binary, "resize", resize=True)
    run_split_descriptor_case(binary)
    if len(sys.argv) == 3:
        run_editor_case(Path(sys.argv[2]).resolve())
    elif len(sys.argv) == 4:
        run_editor_case(Path(sys.argv[2]).resolve())
        run_virtual_list_case(Path(sys.argv[3]).resolve())
    print(
        "PTY lifecycle tests passed "
        "(normal, implicit, error, host, control-c, resize, split descriptors"
        + (", editor" if len(sys.argv) >= 3 else "")
        + (", virtual-list" if len(sys.argv) == 4 else "")
        + ")."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
