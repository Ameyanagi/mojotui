"""Real-filesystem save child for permission and error-path integration tests."""

from std.sys import argv
from mojotui import LocalFileService


def main() raises:
    var args = argv()
    if len(args) != 3:
        raise Error("file save probe requires destination and temporary path")
    _ = LocalFileService().save_atomic(
        args[1].copy(), args[2].copy(), "synthetic replacement only\n"
    )
