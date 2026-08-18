from std.collections import List
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from mojotui import (
    Command,
    RuntimeAdapter,
    RuntimeScope,
    Subscription,
    SubscriptionDelta,
)


struct AdapterEffect(Copyable):
    var value: Int

    def __init__(out self, value: Int):
        self.value = value


struct AdapterMessage(Copyable):
    var value: Int

    def __init__(out self, value: Int):
        self.value = value


struct RecordingAdapter(RuntimeAdapter):
    comptime Effect = AdapterEffect
    comptime Message = AdapterMessage

    var executed: List[Int]
    var started: List[String]
    var stopped: List[String]
    var pending: List[AdapterMessage]
    var close_count: Int

    def __init__(out self):
        self.executed = List[Int]()
        self.started = List[String]()
        self.stopped = List[String]()
        self.pending = List[AdapterMessage]()
        self.close_count = 0

    def execute(mut self, var command: Command[Self.Effect]) raises:
        self.executed.append(command.effect.value)
        self.pending.append(AdapterMessage(command.effect.value * 2))

    def start(mut self, var subscription: Subscription[Self.Effect]) raises:
        self.started.append(subscription.id)

    def stop(mut self, id: StringSlice) raises:
        self.stopped.append(String(id))

    def take_messages(mut self) raises -> List[Self.Message]:
        var result = self.pending^
        self.pending = List[AdapterMessage]()
        return result^

    def close(mut self) raises:
        self.close_count += 1

    def close_silently(mut self):
        self.close_count += 1


def test_scope_executes_commands_and_transfers_typed_messages() raises:
    var scope = RuntimeScope(RecordingAdapter())
    scope.execute_commands([Command(AdapterEffect(3)), Command(AdapterEffect(5))])
    assert_equal(scope.adapter.executed, [3, 5])
    var messages = scope.take_messages()
    assert_equal(len(messages), 2)
    assert_equal(messages[0].value, 6)
    assert_equal(messages[1].value, 10)
    assert_equal(len(scope.take_messages()), 0)


def test_scope_stops_old_subscriptions_before_starting_new_ones() raises:
    var scope = RuntimeScope(RecordingAdapter())
    scope.apply_subscription_delta(
        SubscriptionDelta(
            [Subscription("clock", AdapterEffect(2), revision=1)],
            ["clock"],
        )
    )
    assert_equal(scope.adapter.stopped, ["clock"])
    assert_equal(scope.adapter.started, ["clock"])


def test_scope_close_is_idempotent_and_rejects_new_work() raises:
    var scope = RuntimeScope(RecordingAdapter())
    scope.close()
    scope.close()
    assert_true(scope.closed)
    assert_equal(scope.adapter.close_count, 1)
    assert_equal(len(scope.take_messages()), 0)
    try:
        scope.execute_commands([Command(AdapterEffect(1))])
    except:
        return
    raise Error("closed runtime scope must reject new commands")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
