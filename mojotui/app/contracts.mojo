"""Statically dispatched model/message/update/view contracts."""

from std.collections import List

from ..core.buffer import Buffer
from ..core.geometry import Rect
from .effects import Subscription, UpdateResult


trait Application(Deinitable, Movable):
    """A typed application whose model is mutated by sequential messages."""

    comptime Model: Deinitable & Movable
    comptime Message: Deinitable & Movable
    comptime Effect: Deinitable & Movable

    def init(mut self) raises -> Self.Model:
        """Create the initial model."""
        ...

    def update(
        mut self, mut model: Self.Model, var message: Self.Message
    ) raises -> UpdateResult[Self.Effect]:
        """Apply one message and return redraw plus typed effect requests."""
        ...

    def view(self, model: Self.Model, area: Rect, mut buffer: Buffer) raises:
        """Render the model without performing effects."""
        ...

    def subscriptions(
        self, model: Self.Model
    ) raises -> List[Subscription[Self.Effect]]:
        """Describe ongoing effect sources using stable identities."""
        ...


def dispatch[
    A: Application
](
    mut application: A,
    mut model: A.Model,
    var message: A.Message,
) raises -> UpdateResult[A.Effect]:
    """Dispatch one concrete message through static generic specialization."""
    return application.update(model, message^)


def subscriptions[
    A: Application
](application: A, model: A.Model) raises -> List[Subscription[A.Effect]]:
    """Collect subscriptions through a statically known application type."""
    return application.subscriptions(model)


def render_application[
    A: Application
](application: A, model: A.Model, area: Rect, mut buffer: Buffer,) raises:
    """Render an application through its statically known contract."""
    application.view(model, area, buffer)
