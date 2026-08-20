"""Backend-independent geometry and cell-buffer primitives."""

from .buffer import Buffer, BufferDifference, BufferWrite
from .capabilities import (
    AdaptiveColor,
    ColorProfile,
    ProfiledColor,
    TerminalAppearance,
    TerminalCapabilities,
)
from .cell import Cell
from .geometry import Point, Rect, Size
from .layout import Constraint, ConstraintKind, Direction, Flex, Layout, Margin
from .style import Color, ColorKind, ModifierSet, Style, StylePatch
from .widget import (
    StatefulWidget,
    Widget,
    render_stateful_widget,
    render_widget,
)
