"""Bounded typed message queues with explicit pressure behavior."""

from std.collections import List, Optional


struct MessageClass:
    """Delivery guarantee selected by the message producer."""

    comptime LOSSLESS = 0
    comptime LATEST = 1


struct EnqueueResult:
    """Observable result of attempting to enqueue one message."""

    comptime ACCEPTED = 0
    comptime COALESCED = 1
    comptime BACKPRESSURE = 2
    comptime DROPPED_COALESCIBLE = 3


struct _QueuedMessage[M: Deinitable & Movable](Movable):
    var message: Optional[Self.M]
    var message_class: Int
    var key: String

    def __init__(
        out self,
        var message: Self.M,
        message_class: Int,
        var key: String = "",
    ):
        self.message = message^
        self.message_class = message_class
        self.key = key^


struct MessageQueue[M: Deinitable & Movable](Movable, Sized):
    """A bounded FIFO that never silently discards lossless messages.

    `LATEST` messages replace an older queued value with the same non-empty
    key. When a lossless message arrives at capacity, the oldest coalescible
    entry is evicted first. If every queued message is lossless, enqueueing
    reports backpressure and leaves the queue unchanged.
    """

    var capacity: Int
    var items: List[_QueuedMessage[Self.M]]

    def __init__(out self, capacity: Int = 256):
        self.capacity = max(capacity, 1)
        self.items = List[_QueuedMessage[Self.M]](capacity=self.capacity)

    def __len__(self) -> Int:
        return len(self.items)

    def is_empty(self) -> Bool:
        return len(self.items) == 0

    def _oldest_coalescible(self) -> Int:
        for index in range(len(self.items)):
            if self.items[index].message_class == MessageClass.LATEST:
                return index
        return -1

    def enqueue_lossless(mut self, var message: Self.M) -> Int:
        """Enqueue or return explicit `BACKPRESSURE` without changing the queue."""
        if len(self.items) < self.capacity:
            self.items.append(_QueuedMessage(message^, MessageClass.LOSSLESS))
            return EnqueueResult.ACCEPTED
        var replaceable = self._oldest_coalescible()
        if replaceable >= 0:
            _ = self.items.pop(replaceable)
            self.items.append(_QueuedMessage(message^, MessageClass.LOSSLESS))
            return EnqueueResult.ACCEPTED
        return EnqueueResult.BACKPRESSURE

    def enqueue_latest(mut self, var key: String, var message: Self.M) -> Int:
        """Coalesce by a stable non-empty key or report an explicit drop."""
        if key == "":
            return EnqueueResult.DROPPED_COALESCIBLE
        for index in range(len(self.items)):
            if (
                self.items[index].message_class == MessageClass.LATEST
                and self.items[index].key == key
            ):
                self.items[index].message = message^
                return EnqueueResult.COALESCED
        if len(self.items) >= self.capacity:
            return EnqueueResult.DROPPED_COALESCIBLE
        self.items.append(_QueuedMessage(message^, MessageClass.LATEST, key^))
        return EnqueueResult.ACCEPTED

    def dequeue(mut self) -> Optional[Self.M]:
        if len(self.items) == 0:
            return None
        var item = self.items.pop(0)
        return item.message.take()
