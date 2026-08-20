"""Typed application contracts and state-management primitives."""

from .adapter import RuntimeAdapter, RuntimeScope
from .contracts import (
    Application,
    InitResult,
    dispatch,
    render_application,
    subscriptions,
)
from .effects import (
    CancellationToken,
    Command,
    ControlFlow,
    OperationId,
    OperationResult,
    OperationTracker,
    Subscription,
    SubscriptionDelta,
    SubscriptionTracker,
    UpdateResult,
    accept_operation_result,
)
from .focus import FocusId, FocusManager
from .host import ApplicationHost, HostSchedule, HostStep, TerminalApplicationHost
from .hit_map import Hit, HitMap
from .keymap import KeyChord, KeyResolution, Keymap, KeymapState
from .queue import EnqueueResult, MessageClass, MessageQueue
from .runtime import ApplicationRuntime, Clock, ManualClock, SystemClock
