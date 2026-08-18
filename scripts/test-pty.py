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
        try:
            exit_code = process.wait(timeout=READ_TIMEOUT_SECONDS)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
            raise AssertionError(f"{mode}: child timed out; output={output!r}") from None

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


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: test-pty.py PATH_TO_SESSION_PROBE", file=sys.stderr)
        return 2
    binary = Path(sys.argv[1]).resolve()
    for mode in ("normal", "implicit", "error"):
        run_case(binary, mode)
    run_case(binary, "control-c", send_control_c=True)
    run_case(binary, "resize", resize=True)
    print(
        "PTY lifecycle tests passed "
        "(normal, implicit, error, control-c, resize)."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
