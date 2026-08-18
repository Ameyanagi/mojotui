from std.testing import TestSuite, assert_equal, assert_false, assert_true

from mojotui import EnqueueResult, MessageQueue


struct Message(Copyable):
    var value: Int

    def __init__(out self, value: Int):
        self.value = value


def test_latest_message_coalesces_by_key() raises:
    var queue = MessageQueue[Message](2)
    assert_equal(queue.enqueue_latest("resize", Message(80)), EnqueueResult.ACCEPTED)
    assert_equal(queue.enqueue_latest("tick", Message(1)), EnqueueResult.ACCEPTED)
    assert_equal(queue.enqueue_latest("resize", Message(120)), EnqueueResult.COALESCED)
    assert_equal(len(queue), 2)
    assert_equal(queue.dequeue().value().value, 120)
    assert_equal(queue.dequeue().value().value, 1)


def test_lossless_message_evicts_coalescible_before_backpressure() raises:
    var queue = MessageQueue[Message](2)
    _ = queue.enqueue_latest("mouse", Message(1))
    _ = queue.enqueue_lossless(Message(2))
    assert_equal(queue.enqueue_lossless(Message(3)), EnqueueResult.ACCEPTED)
    assert_equal(queue.dequeue().value().value, 2)
    assert_equal(queue.dequeue().value().value, 3)


def test_full_lossless_queue_reports_backpressure_without_loss() raises:
    var queue = MessageQueue[Message](2)
    _ = queue.enqueue_lossless(Message(1))
    _ = queue.enqueue_lossless(Message(2))
    assert_equal(queue.enqueue_lossless(Message(3)), EnqueueResult.BACKPRESSURE)
    assert_equal(len(queue), 2)
    assert_equal(queue.dequeue().value().value, 1)
    assert_equal(queue.dequeue().value().value, 2)
    assert_true(queue.is_empty())


def test_new_coalescible_message_reports_drop_at_capacity() raises:
    var queue = MessageQueue[Message](1)
    _ = queue.enqueue_lossless(Message(1))
    assert_equal(
        queue.enqueue_latest("resize", Message(2)),
        EnqueueResult.DROPPED_COALESCIBLE,
    )
    assert_false(queue.is_empty())
    assert_equal(queue.dequeue().value().value, 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
