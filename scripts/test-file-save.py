#!/usr/bin/env python3
"""Native filesystem regression coverage; only synthetic private test files."""
from __future__ import annotations

import os
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

binary = Path(sys.argv[1]).resolve()


def save(target: Path | str, temporary: Path, mask: int = 0o022, *, success=True):
    def configure_child():
        os.umask(mask)

    result = subprocess.run(
        [str(binary), str(target), str(temporary)],
        preexec_fn=configure_child, capture_output=True, text=True, timeout=20,
    )
    assert (result.returncode == 0) == success, (result.returncode, result.stderr)
    return result


with tempfile.TemporaryDirectory(prefix="mojotui-save-tests-") as folder:
    root = Path(folder)
    target, temporary = root / "target", root / "temporary"
    for mask in (0o000, 0o022, 0o077, 0o777):
        for mode in (0o600, 0o640, 0o755):
            target.write_text("synthetic original only")
            target.chmod(mode)
            before = target.stat()
            save(target, temporary, mask)
            after = target.stat()
            assert stat.S_IMODE(after.st_mode) == mode, (mask, mode, oct(after.st_mode))
            assert (after.st_uid, after.st_gid) == (before.st_uid, before.st_gid)
            assert target.read_text() == "synthetic replacement only\n"
            assert not temporary.exists()
            target.unlink()
        save(target, temporary, mask)
        assert stat.S_IMODE(target.stat().st_mode) == (0o600 & ~mask)
        target.chmod(0o600)
        target.unlink()

    target.write_text("original remains")
    target.chmod(0o600)
    temporary.write_text("pre-existing temporary remains")
    save(target, temporary, success=False)
    assert temporary.read_text() == "pre-existing temporary remains"
    assert target.read_text() == "original remains"
    temporary.unlink()

    victim = root / "victim"
    victim.write_text("symlink target remains")
    temporary.symlink_to(victim)
    save(target, temporary, success=False)
    assert temporary.is_symlink() and victim.read_text() == "symlink target remains"
    temporary.unlink()

    # A trailing slash requires the existing regular file to be a directory.
    # Creation/write of the sibling succeed, then the real rename(2) fails.
    # RLIMIT_FSIZE is unsuitable here: it can abort Mojo runtime cache writes
    # before the recoverable filesystem error reaches the cleanup handler.
    failure = save(str(target) + os.sep, temporary, success=False)
    assert failure.returncode > 0, ("rename fixture was terminated by a signal", failure.returncode, failure.stderr)
    assert "atomic file replace failed" in failure.stdout + failure.stderr, (failure.stdout, failure.stderr)
    assert not temporary.exists(), ("failed rename must clean up its own temporary file", failure.returncode, failure.stderr)
    assert target.read_text() == "original remains"
    assert stat.S_IMODE(target.stat().st_mode) == 0o600

    for linked_target in (victim, root / "missing"):
        link = root / "destination-link"
        link.symlink_to(linked_target)
        save(link, temporary, success=False)
        assert link.is_symlink() and not temporary.exists()
        link.unlink()

    directory = root / "directory"
    directory.mkdir()
    save(directory, temporary, success=False)
    assert directory.is_dir() and not temporary.exists()

print("File save tests passed: 12 mode/umask combinations, 4 new-file policies, ownership, exclusive creation, symlinks, special files, failed-rename cleanup.")
