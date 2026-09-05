"""Exercise byte-granular partial writes with multi-byte content."""

from std.collections import List
from std.io import FileDescriptor
from mojotui.platform import write_all


def main() raises:
    var content = String("あ") * 100_000
    try:
        write_all(9, content)
    except error:
        if "terminal write failed" not in String(error):
            raise Error("unexpected write failure: ", error)
        print("RECOVERABLE_UTF8_WRITE_FAILURE", flush=True)
        var storage = List[UInt8](length=1, fill=0)
        var signal = FileDescriptor(0)
        _ = signal.read_bytes(storage)
        write_all(9, content)
        print("COMPLETE_UTF8_WRITE", flush=True)
        return
    raise Error("oversized nonblocking write unexpectedly completed")
