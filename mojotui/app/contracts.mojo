"""Statically dispatched model/message/update/view contracts."""

from std.collections import List, Optional

from ..core.buffer import Buffer
from ..core.geometry import Rect, Size
from ..event.input import InputEvent
from .effects import Command, Subscription, UpdateResult


struct InitResult[
    M: Deinitable & Movable,
    E: Deinitable & Movable,
](Movable):
    """Initial model plus finite startup effects."""

    var _model: Optional[Self.M]
    var _commands: List[Command[Self.E]]

    def __init__(
        out self,
        var model: Self.M,
        var commands: List[Command[Self.E]] = List[Command[Self.E]](),
    ):
        self._model = model^
        self._commands = commands^

    @staticmethod
    def ready(var model: Self.M) -> Self:
        return Self(model^)

    def take_model(mut self) -> Self.M:
        return self._model.take()

    def take_commands(mut self) -> List[Command[Self.E]]:
        var commands = self._commands^
        self._commands = List[Command[Self.E]]()
        return commands^


trait Application(Deinitable, Movable):
    """A typed application whose model is mutated by sequential messages."""

    comptime Model: Deinitable & Movable
    comptime Message: Deinitable & Movable
    comptime Effect: Deinitable & Movable

    def init(mut self) raises -> InitResult[Self.Model, Self.Effect]:
        """Create the initial model and optional startup commands."""
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
        return []

    def on_input(
        self, model: Self.Model, var event: InputEvent
    ) raises -> Optional[Self.Message]:
        """Map terminal input to an application message, if relevant."""
        return None

    def on_tick(self, model: Self.Model, now_ns: Int) raises -> Optional[Self.Message]:
        """Map a host timer observation to an application message."""
        return None

    def on_resize(self, model: Self.Model, size: Size) raises -> Optional[Self.Message]:
        """Map a terminal resize to an application message."""
        return None


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
