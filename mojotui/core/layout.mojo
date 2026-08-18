"""Deterministic one-dimensional layout allocation."""

from std.collections import List

from .geometry import Rect, _saturating_add_nonnegative


struct Constraint(Copyable):
    """The sizing rule for one layout segment."""

    comptime LENGTH = 0
    comptime MIN = 1
    comptime MAX = 2
    comptime PERCENTAGE = 3
    comptime RATIO = 4
    comptime FILL = 5

    var kind: Int
    var value: Int
    var denominator: Int

    def __init__(
        out self,
        kind: Int,
        value: Int = 0,
        denominator: Int = 1,
    ):
        self.kind = kind if kind >= Self.LENGTH and kind <= Self.FILL else Self.FILL
        self.value = max(value, 0)
        self.denominator = max(1, min(denominator, 1_000_000))

    @staticmethod
    def length(value: Int) -> Self:
        return Self(Self.LENGTH, value)

    @staticmethod
    def minimum(value: Int) -> Self:
        return Self(Self.MIN, value)

    @staticmethod
    def maximum(value: Int) -> Self:
        return Self(Self.MAX, value)

    @staticmethod
    def percentage(value: Int) -> Self:
        return Self(Self.PERCENTAGE, min(max(value, 0), 100), 100)

    @staticmethod
    def ratio(numerator: Int, denominator: Int) -> Self:
        var safe_denominator = max(1, min(denominator, 1_000_000))
        return Self(
            Self.RATIO,
            min(max(numerator, 0), safe_denominator),
            safe_denominator,
        )

    @staticmethod
    def fill(weight: Int = 1) -> Self:
        return Self(Self.FILL, max(1, min(weight, 1_000_000)))


struct Flex:
    """Placement of space left after all constraints are satisfied."""

    comptime START = 0
    comptime CENTER = 1
    comptime END = 2
    comptime SPACE_BETWEEN = 3


struct Layout(Copyable):
    """Split a rectangle along one axis without a general constraint solver.

    Exact, percentage, and ratio constraints are allocated in declaration
    order. `minimum`, `maximum`, and weighted `fill` segments share remaining
    space. When the requested bases do not fit, later segments clip first.
    """

    comptime HORIZONTAL = 0
    comptime VERTICAL = 1

    var direction: Int
    var constraints: List[Constraint]
    var spacing: Int
    var flex: Int

    def __init__(
        out self,
        direction: Int,
        var constraints: List[Constraint],
        spacing: Int = 0,
        flex: Int = Flex.START,
    ):
        self.direction = (
            direction if direction == Self.HORIZONTAL
            or direction == Self.VERTICAL else Self.HORIZONTAL
        )
        self.constraints = constraints^
        self.spacing = max(spacing, 0)
        self.flex = (
            flex if flex >= Flex.START and flex <= Flex.SPACE_BETWEEN else Flex.START
        )

    @staticmethod
    def horizontal(
        var constraints: List[Constraint],
        spacing: Int = 0,
        flex: Int = Flex.START,
    ) -> Self:
        return Self(Self.HORIZONTAL, constraints^, spacing, flex)

    @staticmethod
    def vertical(
        var constraints: List[Constraint],
        spacing: Int = 0,
        flex: Int = Flex.START,
    ) -> Self:
        return Self(Self.VERTICAL, constraints^, spacing, flex)

    @staticmethod
    def _scaled(total: Int, numerator: Int, denominator: Int) -> Int:
        if total <= 0 or numerator <= 0:
            return 0
        var quotient = total // denominator
        var remainder = total % denominator
        return quotient * numerator + (remainder * numerator) // denominator

    def _base_size(self, constraint: Constraint, available: Int) -> Int:
        if constraint.kind == Constraint.LENGTH:
            return min(constraint.value, available)
        if constraint.kind == Constraint.MIN:
            return min(constraint.value, available)
        if constraint.kind == Constraint.PERCENTAGE:
            return Self._scaled(available, constraint.value, 100)
        if constraint.kind == Constraint.RATIO:
            return Self._scaled(available, constraint.value, constraint.denominator)
        return 0

    def _growth_weight(self, constraint: Constraint) -> Int:
        if constraint.kind == Constraint.FILL:
            return constraint.value
        if constraint.kind == Constraint.MIN or constraint.kind == Constraint.MAX:
            return 1
        return 0

    def _can_grow(self, constraint: Constraint, current: Int) -> Bool:
        if constraint.kind == Constraint.MAX:
            return current < constraint.value
        return constraint.kind == Constraint.MIN or constraint.kind == Constraint.FILL

    def _grow(
        self,
        mut sizes: List[Int],
        mut remaining: Int,
    ) -> Int:
        while remaining > 0:
            var total_weight = 0
            for index in range(len(self.constraints)):
                var constraint = self.constraints[index].copy()
                if self._can_grow(constraint, sizes[index]):
                    var weight = self._growth_weight(constraint)
                    if weight > Int.MAX - total_weight:
                        total_weight = Int.MAX
                    else:
                        total_weight += weight
            if total_weight == 0:
                break

            var round_budget = remaining
            var grants = List[Int](length=len(sizes), fill=0)
            var granted = 0
            for index in range(len(self.constraints)):
                var constraint = self.constraints[index].copy()
                if not self._can_grow(constraint, sizes[index]):
                    continue
                var share = Self._scaled(
                    round_budget,
                    self._growth_weight(constraint),
                    total_weight,
                )
                if constraint.kind == Constraint.MAX:
                    share = min(share, constraint.value - sizes[index])
                share = min(share, round_budget - granted)
                grants[index] = share
                granted += share

            if granted == 0:
                for index in range(len(self.constraints)):
                    if remaining == 0:
                        break
                    var constraint = self.constraints[index].copy()
                    if self._can_grow(constraint, sizes[index]):
                        sizes[index] += 1
                        remaining -= 1
            else:
                for index in range(len(sizes)):
                    sizes[index] += grants[index]
                remaining -= granted
        return remaining

    def split(self, area: Rect) -> List[Rect]:
        """Allocate non-overlapping child rectangles contained by `area`."""
        var count = len(self.constraints)
        var result = List[Rect](capacity=count)
        if count == 0:
            return result^

        var axis = area.width if self.direction == Self.HORIZONTAL else area.height
        var gap_count = count - 1
        var gaps = List[Int](length=gap_count, fill=0)
        var available = axis
        for index in range(gap_count):
            var gap = min(self.spacing, available)
            gaps[index] = gap
            available -= gap

        var sizes = List[Int](length=count, fill=0)
        var remaining = available
        for index in range(count):
            var size = min(
                self._base_size(self.constraints[index], available), remaining
            )
            sizes[index] = size
            remaining -= size

        remaining = self._grow(sizes, remaining)

        var leading = 0
        if self.flex == Flex.CENTER:
            leading = remaining // 2
        elif self.flex == Flex.END:
            leading = remaining
        elif self.flex == Flex.SPACE_BETWEEN and gap_count > 0:
            var extra = remaining // gap_count
            var remainder = remaining % gap_count
            for index in range(gap_count):
                gaps[index] += extra + (1 if index < remainder else 0)

        var cursor = leading
        for index in range(count):
            if self.direction == Self.HORIZONTAL:
                result.append(
                    Rect(
                        _saturating_add_nonnegative(area.x, cursor),
                        area.y,
                        sizes[index],
                        area.height,
                    )
                )
            else:
                result.append(
                    Rect(
                        area.x,
                        _saturating_add_nonnegative(area.y, cursor),
                        area.width,
                        sizes[index],
                    )
                )
            cursor += sizes[index]
            if index < gap_count:
                cursor += gaps[index]
        return result^
