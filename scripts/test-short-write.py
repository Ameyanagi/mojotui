#!/usr/bin/env python3
"""Prove checked ANSI writes reject and recover from a real short write."""

from __future__ import annotations

import os
import select
import subprocess
import sys
import time
from pathlib import Path


OUTPUT_DESCRIPTOR = 9
TIMEOUT_SECONDS = 20.0


def wait_for_marker(process: subprocess.Popen[bytes], marker: bytes) -> bytes:
    assert process.stdout is not None
    output = bytearray()
    deadline = time.monotonic() + TIMEOUT_SECONDS
    while marker not in output and time.monotonic() < deadline:
        readable, _, _ = select.select([process.stdout], [], [], 0.1)
        if readable:
            output.extend(os.read(process.stdout.fileno(), 4096))
        if process.poll() is not None and not readable:
            break
    if marker not in output:
        raise AssertionError(
            f"probe did not emit {marker!r}; exit={process.poll()}, output={output!r}"
        )
    return bytes(output)


def drain_available(read_descriptor: int) -> int:
    count = 0
    while True:
        try:
            chunk = os.read(read_descriptor, 65536)
        except BlockingIOError:
            return count
        if not chunk:
            return count
        count += len(chunk)


def fill_pipe(write_descriptor: int) -> int:
    count = 0
    block = b"p" * 65536
    while True:
        try:
            count += os.write(write_descriptor, block)
        except BlockingIOError:
            return count


def run(binary: Path) -> None:
    read_descriptor, write_descriptor = os.pipe()
    os.set_blocking(read_descriptor, False)
    os.set_blocking(write_descriptor, False)
    try:
        full_bytes = fill_pipe(write_descriptor)
        opened_bytes = 0
        while opened_bytes < 16384:
            opened_bytes += len(os.read(read_descriptor, 16384 - opened_bytes))
        prefilled_bytes = full_bytes - opened_bytes
        try:
            saved_output = os.dup(OUTPUT_DESCRIPTOR)
        except OSError:
            saved_output = None
        os.dup2(write_descriptor, OUTPUT_DESCRIPTOR, inheritable=True)
        try:
            process = subprocess.Popen(
                [str(binary)],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                close_fds=True,
                pass_fds=(OUTPUT_DESCRIPTOR,),
            )
        finally:
            if saved_output is None:
                os.close(OUTPUT_DESCRIPTOR)
            else:
                os.dup2(saved_output, OUTPUT_DESCRIPTOR)
                os.close(saved_output)
        control = wait_for_marker(process, b"FAILED_WITHOUT_COMMIT")
        initial_bytes = drain_available(read_descriptor) - prefilled_bytes
        if initial_bytes <= 0 or initial_bytes >= 1_000_000:
            raise AssertionError(
                "expected a real partial write, observed "
                f"{initial_bytes} bytes; control={control!r}"
            )

        # File-status flags are shared by the duplicated descriptor in the
        # child. Repair the transport and drain concurrently with its retry.
        os.set_blocking(write_descriptor, True)
        assert process.stdin is not None
        process.stdin.write(b"x")
        process.stdin.flush()

        assert process.stdout is not None
        watched = [read_descriptor, process.stdout.fileno()]
        deadline = time.monotonic() + TIMEOUT_SECONDS
        while b"RECOVERED_WITH_FULL_REDRAW" not in control and time.monotonic() < deadline:
            readable, _, _ = select.select(watched, [], [], 0.1)
            for descriptor in readable:
                if descriptor == read_descriptor:
                    drain_available(read_descriptor)
                else:
                    control += os.read(descriptor, 4096)
            if process.poll() is not None and not readable:
                break

        if b"RECOVERED_WITH_FULL_REDRAW" not in control:
            stderr = process.stderr.read() if process.stderr is not None else b""
            raise AssertionError(
                "probe did not recover after transport repair; "
                f"exit={process.poll()}, stdout={control!r}, stderr={stderr!r}"
            )
        process.wait(timeout=TIMEOUT_SECONDS)
        if process.returncode != 0:
            stderr = process.stderr.read() if process.stderr is not None else b""
            raise AssertionError(
                f"probe exited {process.returncode}; stderr={stderr!r}"
            )
    finally:
        os.close(read_descriptor)
        os.close(write_descriptor)


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: test-short-write.py PATH_TO_PROBE", file=sys.stderr)
        return 2
    run(Path(sys.argv[1]).resolve())
    print("ANSI short-write recovery test passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
