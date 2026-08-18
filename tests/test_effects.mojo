from std.testing import TestSuite, assert_equal, assert_false, assert_true

from mojotui import (
    Command,
    OperationResult,
    OperationTracker,
    Subscription,
    SubscriptionTracker,
    accept_operation_result,
)


struct SearchEffect(Copyable):
    var query: String

    def __init__(out self, var query: String):
        self.query = query^


struct SearchMessage(Copyable):
    var result: String

    def __init__(out self, var result: String):
        self.result = result^


def test_new_generation_rejects_stale_result() raises:
    var tracker = OperationTracker()
    var first = tracker.begin("search")
    var second = tracker.begin("search")
    assert_false(tracker.is_current(first))
    assert_true(tracker.is_current(second))

    var stale = accept_operation_result(
        tracker, OperationResult(first, SearchMessage("old"))
    )
    assert_false(stale)
    var current = accept_operation_result(
        tracker, OperationResult(second, SearchMessage("new"))
    )
    assert_true(current)
    assert_equal(current.value().result, "new")


def test_cancel_invalidates_value_token() raises:
    var tracker = OperationTracker()
    var operation = tracker.begin("load")
    var command = Command.tracked(SearchEffect("file"), operation)
    var token = command.cancellation_token()
    assert_true(token)
    assert_false(tracker.is_cancelled(token.value()))
    tracker.cancel("load")
    assert_true(tracker.is_cancelled(token.value()))


def test_operation_keys_advance_independently() raises:
    var tracker = OperationTracker()
    var search = tracker.begin("search")
    var save = tracker.begin("save")
    _ = tracker.begin("search")
    assert_false(tracker.is_current(search))
    assert_true(tracker.is_current(save))


def test_subscription_reconciliation_uses_stable_ids_and_revisions() raises:
    var tracker = SubscriptionTracker()
    var initial = tracker.reconcile(
        [
            Subscription("input", SearchEffect("stdin")),
            Subscription("clock", SearchEffect("100ms")),
        ]
    )
    assert_equal(len(initial.starts), 2)
    assert_equal(len(initial.stops), 0)

    var unchanged = tracker.reconcile(
        [
            Subscription("input", SearchEffect("ignored-change")),
            Subscription("clock", SearchEffect("100ms")),
        ]
    )
    assert_equal(len(unchanged.starts), 0)
    assert_equal(len(unchanged.stops), 0)

    var revised = tracker.reconcile(
        [Subscription("clock", SearchEffect("16ms"), revision=1)]
    )
    assert_equal(len(revised.starts), 1)
    assert_equal(revised.starts[0].id, "clock")
    assert_equal(len(revised.stops), 2)
    assert_equal(revised.stops[0], "input")
    assert_equal(revised.stops[1], "clock")
    assert_equal(tracker.active_count(), 1)


def test_duplicate_subscription_ids_are_rejected() raises:
    var tracker = SubscriptionTracker()
    try:
        _ = tracker.reconcile(
            [
                Subscription("clock", SearchEffect("one")),
                Subscription("clock", SearchEffect("two")),
            ]
        )
    except:
        return
    raise Error("expected duplicate subscription rejection")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
