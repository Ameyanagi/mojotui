# Runtime integration

Mojotui owns an application loop, not a general-purpose task executor. Effects
leave `update` as typed `Command[Effect]` values. Ongoing work is described by
stable-ID `Subscription[Effect]` values. Completed work returns concrete
application messages.

The public bridge is `RuntimeAdapter`, which is bound to one associated
`ApplicationType`. That compile-time relationship proves its command effect
and completed message types match the application. A reusable adapter can be a
generic struct parameterized by the concrete application. The adapter has seven
responsibilities:

1. execute finite commands;
2. start stable-ID subscriptions;
3. cancel and join a subscription before replacement;
4. transfer completed typed messages to the application host;
5. optionally report its next monotonic deadline;
6. advance runtime-owned timers when that deadline is reached; and
7. cancel and join every owned task on close.

`RuntimeScope` applies those operations and rejects work after close. Its
destructor calls the adapter's non-raising `close_silently()` path during
unwinding. Operation generations and `CancellationToken` values let hosts
cooperate with cancellation; `OperationTracker` still rejects stale results
when an underlying operation cannot be interrupted.

## Future Mojo runtime adapter

The pinned Mojo distribution contains private, unfinished runtime internals.
Mojotui does not import them. A future adapter for a stable public Mojo runtime
should keep runtime futures, task handles, channels, and executors inside its
concrete implementation of `RuntimeAdapter`. None of those types should leak
into widgets, application models, effects, or editor APIs.

All tasks must be scoped to the adapter. `stop(id)` cancels and joins the named
subscription. `close()` cancels and joins all remaining commands and
subscriptions before returning. `close_silently()` must make the same attempt
when an error prevents explicit close. Detached tasks are not supported.

`ApplicationHost` owns the model runtime, adapter scope, and terminal frame
transactions. `TerminalApplicationHost` additionally owns `TerminalSession`,
`PosixReactor`, and `InputParser`; it maps input, tick, and resize observations
through the application's optional hooks. `HostSchedule` keeps application
ticks, incomplete Escape input, frame cadence, and adapter deadlines separate,
then derives the reactor timeout from their nearest value. Continuous input or
wakeup traffic therefore cannot starve periodic ticks. `SessionOptions` selects
fullscreen or inline-compatible terminal lifecycle behavior.

The host transfers adapter messages into Mojotui's bounded `MessageQueue` and
retains any unconsumed tail in a host-owned backlog. Each turn processes at
most `max_messages_per_step`, renders at a bounded cadence, and reconciles
subscriptions after the batch. Keys and paste remain lossless. Tick and resize
messages use stable-key latest-value coalescing.

The host may give `PosixReactor` the read end of a wakeup pipe. An adapter writes
one or more bytes after enqueueing completed messages; the reactor reports
`wakeup_ready`, and the host drains both the pipe and the adapter messages.
