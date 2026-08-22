"""Deterministic one-dimensional layout allocation."""

from std.collections import List

from .geometry import Rect, _saturating_add_nonnegative


def _saturating_product(left: Int, right: Int) -> Int:
    if left <= 0 or right <= 0:
        return 0
    if left > Int.MAX // right:
        return Int.MAX
    return left * right


struct Margin(Copyable):
    """Symmetric horizontal and vertical layout inset."""

    var horizontal: Int
    var vertical: Int

    def __init__(out self, horizontal: Int = 0, vertical: Int = 0):
        self.horizontal = max(horizontal, 0)
        self.vertical = max(vertical, 0)

    @staticmethod
    def uniform(value: Int) -> Self:
        return Self(value, value)


struct ConstraintKind(Copyable, Equatable, ImplicitlyCopyable):
    """Nominal sizing-rule discriminator used by `Constraint`."""

    comptime LENGTH = ConstraintKind(0, _validated=True)
    comptime MIN = ConstraintKind(1, _validated=True)
    comptime MAX = ConstraintKind(2, _validated=True)
    comptime PERCENTAGE = ConstraintKind(3, _validated=True)
    comptime RATIO = ConstraintKind(4, _validated=True)
    comptime FILL = ConstraintKind(5, _validated=True)

    var _value: Int

    def __init__(out self, value: Int, *, _validated: Bool):
        self._value = value

    def __init__(out self, value: Int) raises:
        if value < 0 or value > 5:
            raise Error(
                String("layout constraint kind must be within [0, 5]; got ", value)
            )
        self._value = value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value


struct Constraint(Copyable):
    """The sizing rule for one layout segment."""

    comptime LENGTH = ConstraintKind.LENGTH
    comptime MIN = ConstraintKind.MIN
    comptime MAX = ConstraintKind.MAX
    comptime PERCENTAGE = ConstraintKind.PERCENTAGE
    comptime RATIO = ConstraintKind.RATIO
    comptime FILL = ConstraintKind.FILL

    var kind: ConstraintKind
    var value: Int
    var denominator: Int

    def __init__(
        out self,
        kind: ConstraintKind,
        value: Int = 0,
        denominator: Int = 1,
    ):
        self.kind = kind
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
        return Self(Self.PERCENTAGE, min(max(value, 0), 1_000_000), 100)

    @staticmethod
    def ratio(numerator: Int, denominator: Int) -> Self:
        var safe_denominator = max(1, min(denominator, 1_000_000))
        return Self(
            Self.RATIO,
            min(max(numerator, 0), 1_000_000),
            safe_denominator,
        )

    @staticmethod
    def fill(weight: Int = 1) -> Self:
        return Self(Self.FILL, min(max(weight, 0), 1_000_000))


struct Flex(Copyable, Equatable, ImplicitlyCopyable):
    """Placement of space left after all constraints are satisfied."""

    comptime START = Flex(0, _validated=True)
    comptime CENTER = Flex(1, _validated=True)
    comptime END = Flex(2, _validated=True)
    comptime SPACE_BETWEEN = Flex(3, _validated=True)
    comptime SPACE_EVENLY = Flex(4, _validated=True)
    comptime SPACE_AROUND = Flex(5, _validated=True)

    var _value: Int

    def __init__(out self, value: Int, *, _validated: Bool):
        self._value = value

    def __init__(out self, value: Int) raises:
        if value < 0 or value > 5:
            raise Error(String("layout flex mode must be within [0, 5]; got ", value))
        self._value = value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value


struct Direction(Copyable, Equatable, ImplicitlyCopyable):
    """Nominal axis along which a layout divides its area."""

    comptime HORIZONTAL = Direction(0, _validated=True)
    comptime VERTICAL = Direction(1, _validated=True)

    var _value: Int

    def __init__(out self, value: Int, *, _validated: Bool):
        self._value = value

    def __init__(out self, value: Int) raises:
        if value < 0 or value > 1:
            raise Error(String("layout direction must be within [0, 1]; got ", value))
        self._value = value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value


struct Layout(Copyable):
    """Split a rectangle along one axis without a general constraint solver.

    Ratatui-compatible non-legacy priorities resolve over-constrained segments:
    minimum, maximum, length, percentage, ratio, then fill. Weighted fills
    consume remaining segment space. Flexible spacers receive only the excess
    left after segment growth.
    """

    comptime HORIZONTAL = Direction.HORIZONTAL
    comptime VERTICAL = Direction.VERTICAL

    var direction: Direction
    var constraints: List[Constraint]
    var _spacing: Int
    var _flex: Flex
    var _margin: Margin

    def __init__(
        out self,
        direction: Direction,
        var constraints: List[Constraint],
        spacing: Int = 0,
        flex: Flex = Flex.START,
        margin: Margin = Margin(),
    ):
        self.direction = direction
        self.constraints = constraints^
        self._spacing = max(spacing, 0)
        self._flex = flex
        self._margin = margin.copy()

    @staticmethod
    def horizontal(
        var constraints: List[Constraint],
        spacing: Int = 0,
        flex: Flex = Flex.START,
        margin: Margin = Margin(),
    ) -> Self:
        return Self(Self.HORIZONTAL, constraints^, spacing, flex, margin)

    @staticmethod
    def vertical(
        var constraints: List[Constraint],
        spacing: Int = 0,
        flex: Flex = Flex.START,
        margin: Margin = Margin(),
    ) -> Self:
        return Self(Self.VERTICAL, constraints^, spacing, flex, margin)

    def with_margin(self, margin: Margin) -> Self:
        var result = self.copy()
        result._margin = margin.copy()
        return result^

    def with_uniform_margin(self, margin: Int) -> Self:
        return self.with_margin(Margin.uniform(margin))

    def margin(self, margin: Int) -> Self:
        """Set a uniform margin using Ratatui-compatible naming."""
        return self.with_uniform_margin(margin)

    def horizontal_margin(self, margin: Int) -> Self:
        var result = self.copy()
        result._margin.horizontal = max(margin, 0)
        return result^

    def vertical_margin(self, margin: Int) -> Self:
        var result = self.copy()
        result._margin.vertical = max(margin, 0)
        return result^

    def with_spacing(self, spacing: Int) -> Self:
        var result = self.copy()
        result._spacing = max(spacing, 0)
        return result^

    def spacing(self, spacing: Int) -> Self:
        """Set nonnegative inter-segment spacing."""
        return self.with_spacing(spacing)

    def with_flex(self, flex: Flex) -> Self:
        var result = self.copy()
        result._flex = flex
        return result^

    def flex(self, flex: Flex) -> Self:
        """Set excess-space placement using Ratatui-compatible naming."""
        return self.with_flex(flex)

    @staticmethod
    def _scaled(total: Int, numerator: Int, denominator: Int) -> Int:
        if total <= 0 or numerator <= 0:
            return 0
        var quotient = total // denominator
        var remainder = total % denominator
        var whole = _saturating_product(quotient, numerator)
        var partial = _saturating_product(remainder, numerator) // denominator
        if whole > Int.MAX - partial:
            return Int.MAX
        return whole + partial

    @staticmethod
    def _rounded_scaled(total: Int, numerator: Int, denominator: Int) -> Int:
        if total <= 0 or numerator <= 0:
            return 0
        if numerator >= denominator:
            return total
        var floor = Self._scaled(total, numerator, denominator)
        var remainder = total % denominator
        var fractional = remainder * numerator % denominator
        return floor + (1 if fractional * 2 >= denominator else 0)

    def _base_size(self, constraint: Constraint, axis: Int) -> Int:
        if constraint.kind == Constraint.LENGTH:
            return min(constraint.value, axis)
        if constraint.kind == Constraint.MIN:
            return min(constraint.value, axis)
        if constraint.kind == Constraint.MAX:
            return min(constraint.value, axis)
        if constraint.kind == Constraint.PERCENTAGE:
            return min(axis, Self._scaled(axis, constraint.value, 100))
        if constraint.kind == Constraint.RATIO:
            return min(
                axis,
                Self._scaled(axis, constraint.value, constraint.denominator),
            )
        return 0

    def _priority(self, constraint: Constraint) -> Int:
        if constraint.kind == Constraint.MIN:
            return 0
        if constraint.kind == Constraint.MAX:
            return 1
        if constraint.kind == Constraint.LENGTH:
            return 2
        if constraint.kind == Constraint.PERCENTAGE:
            return 3
        if constraint.kind == Constraint.RATIO:
            return 4
        return 5

    def _allocate_bases(
        self,
        mut sizes: List[Int],
        capacity: Int,
        axis: Int,
    ) -> Int:
        var remaining = capacity
        for priority in range(5):
            if remaining == 0:
                break
            var desired_total = 0
            for index in range(len(self.constraints)):
                var constraint = self.constraints[index].copy()
                if self._priority(constraint) == priority:
                    var desired = self._base_size(constraint, axis)
                    if desired_total > Int.MAX - desired:
                        desired_total = Int.MAX
                    else:
                        desired_total += desired
            if desired_total == 0:
                continue
            if desired_total <= remaining:
                for index in range(len(self.constraints)):
                    var constraint = self.constraints[index].copy()
                    if self._priority(constraint) == priority:
                        sizes[index] = self._base_size(constraint, axis)
                remaining -= desired_total
                continue

            var cumulative = 0
            var allocated = 0
            for index in range(len(self.constraints)):
                var constraint = self.constraints[index].copy()
                if self._priority(constraint) != priority:
                    continue
                cumulative += self._base_size(constraint, axis)
                var boundary = Self._rounded_scaled(
                    remaining, cumulative, desired_total
                )
                sizes[index] = boundary - allocated
                allocated = boundary
            remaining = 0
        return remaining

    def _grow(
        self,
        mut sizes: List[Int],
        mut remaining: Int,
    ) -> Int:
        if remaining == 0:
            return 0
        var fill_count = 0
        var fill_weight = 0
        for index in range(len(self.constraints)):
            var constraint = self.constraints[index].copy()
            if constraint.kind == Constraint.FILL:
                fill_count += 1
                fill_weight += constraint.value

        if fill_count > 0:
            var total_weight = fill_weight if fill_weight > 0 else fill_count
            var cumulative = 0
            var allocated = 0
            for index in range(len(self.constraints)):
                var constraint = self.constraints[index].copy()
                if constraint.kind != Constraint.FILL:
                    continue
                var weight = constraint.value if fill_weight > 0 else 1
                cumulative += weight
                var boundary = Self._rounded_scaled(remaining, cumulative, total_weight)
                sizes[index] += boundary - allocated
                allocated = boundary
            return 0

        var minimum_count = 0
        for index in range(len(self.constraints)):
            if self.constraints[index].kind == Constraint.MIN:
                minimum_count += 1
        if minimum_count == 0:
            return remaining

        var seen = 0
        var allocated = 0
        for index in range(len(self.constraints)):
            if self.constraints[index].kind != Constraint.MIN:
                continue
            seen += 1
            var boundary = Self._rounded_scaled(remaining, seen, minimum_count)
            sizes[index] += boundary - allocated
            allocated = boundary
        return 0

    @staticmethod
    def _distribute_equal(
        mut spacers: List[Int],
        first: Int,
        count: Int,
        total: Int,
    ):
        if count <= 0:
            return
        var allocated = 0
        for offset in range(count):
            var boundary = Self._rounded_scaled(total, offset + 1, count)
            spacers[first + offset] = boundary - allocated
            allocated = boundary

    @staticmethod
    def _distribute_around(mut spacers: List[Int], total: Int):
        var count = len(spacers) - 1
        if count <= 0:
            return
        var denominator = count * 2
        var allocated = 0
        for index in range(len(spacers)):
            var cumulative_units = min(index * 2 + 1, denominator)
            var boundary = Self._rounded_scaled(total, cumulative_units, denominator)
            spacers[index] = boundary - allocated
            allocated = boundary

    def split(self, area: Rect) -> List[Rect]:
        """Allocate non-overlapping child rectangles contained by `area`."""
        var count = len(self.constraints)
        var result = List[Rect](capacity=count)
        if count == 0:
            return result^

        var inner = area.inset(self._margin.horizontal, self._margin.vertical)
        var axis = inner.width if self.direction == Self.HORIZONTAL else inner.height
        var gap_count = count - 1
        var spacer_units = gap_count
        if self._flex == Flex.SPACE_EVENLY:
            spacer_units = count + 1
        elif self._flex == Flex.SPACE_AROUND:
            spacer_units = count * 2
        var minimum_spacers = min(
            axis, _saturating_product(self._spacing, spacer_units)
        )
        var available = axis - minimum_spacers

        var sizes = List[Int](length=count, fill=0)
        var remaining = self._allocate_bases(sizes, available, axis)
        remaining = self._grow(sizes, remaining)

        if self._flex == Flex.SPACE_BETWEEN and count == 1:
            sizes[0] = axis
            remaining = 0
            minimum_spacers = 0

        var spacers = List[Int](length=count + 1, fill=0)
        if self._flex == Flex.SPACE_BETWEEN:
            Self._distribute_equal(spacers, 1, gap_count, minimum_spacers + remaining)
        elif self._flex == Flex.SPACE_EVENLY:
            Self._distribute_equal(spacers, 0, count + 1, minimum_spacers + remaining)
        elif self._flex == Flex.SPACE_AROUND:
            Self._distribute_around(spacers, minimum_spacers + remaining)
        else:
            Self._distribute_equal(spacers, 1, gap_count, minimum_spacers)
            if self._flex == Flex.CENTER:
                spacers[0] = Self._rounded_scaled(remaining, 1, 2)
                spacers[count] = remaining - spacers[0]
            elif self._flex == Flex.END:
                spacers[0] = remaining
            else:
                spacers[count] = remaining

        var cursor = spacers[0]
        for index in range(count):
            if self.direction == Self.HORIZONTAL:
                result.append(
                    Rect(
                        _saturating_add_nonnegative(inner.x, cursor),
                        inner.y,
                        sizes[index],
                        inner.height,
                    )
                )
            else:
                result.append(
                    Rect(
                        inner.x,
                        _saturating_add_nonnegative(inner.y, cursor),
                        inner.width,
                        sizes[index],
                    )
                )
            cursor += sizes[index]
            cursor += spacers[index + 1]
        return result^
