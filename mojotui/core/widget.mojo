"""Statically dispatched immediate-mode widget contracts."""

from .buffer import Buffer
from .geometry import Rect


trait Widget:
    """A value that renders immediately into a borrowed buffer."""

    def render(self, area: Rect, mut buffer: Buffer):
        ...


trait StatefulWidget:
    """A widget rendered with caller-owned, explicitly mutable state."""

    comptime State: Deinitable & Movable

    def render(self, area: Rect, mut buffer: Buffer, mut state: Self.State) raises:
        ...


def render_widget[W: Widget](widget: W, area: Rect, mut buffer: Buffer):
    """Render a concrete widget without runtime type erasure."""
    widget.render(area, buffer)


def render_stateful_widget[
    W: StatefulWidget
](widget: W, area: Rect, mut buffer: Buffer, mut state: W.State) raises:
    """Render a concrete stateful widget without runtime type erasure."""
    widget.render(area, buffer, state)
