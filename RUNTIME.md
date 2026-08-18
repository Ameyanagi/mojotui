# Runtime integration

Mojotui owns an application loop, not a general-purpose task executor. Effects
leave `update` as typed `Command[Effect]` values. Ongoing work is described by
stable-ID `Subscription[Effect]` values. Completed work returns concrete
application messages.

The public bridge is `RuntimeAdapter`, which has associated `Effect` and
`Message` types and five responsibilities:

1. execute finite commands;
2. start stable-ID subscriptions;
3. cancel and join a subscription before replacement;
4. transfer completed typed messages to the application host; and
5. cancel and join every owned task on close.

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

The host drains adapter messages into Mojotui's bounded `MessageQueue`. It must
honor `BACKPRESSURE` for lossless messages and may use stable-key coalescing
only for messages deliberately classified as latest-value events.

The host may give `PosixReactor` the read end of a wakeup pipe. An adapter writes
one or more bytes after enqueueing completed messages; the reactor reports
`wakeup_ready`, and the host drains both the pipe and the adapter messages.
