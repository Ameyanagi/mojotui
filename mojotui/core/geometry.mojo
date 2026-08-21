"""Signed terminal geometry with clipping-friendly operations."""


def _nonnegative(value: Int) -> Int:
    return value if value > 0 else 0


def _minimum(left: Int, right: Int) -> Int:
    return left if left < right else right


def _maximum(left: Int, right: Int) -> Int:
    return left if left > right else right


def _saturating_add_nonnegative(value: Int, amount: Int) -> Int:
    """Add a nonnegative amount without overflowing Int."""
    if amount <= 0:
        return value
    if value > Int.MAX - amount:
        return Int.MAX
    return value + amount


def _saturating_add(value: Int, amount: Int) -> Int:
    """Add signed coordinates without overflowing Int."""
    if amount > 0 and value > Int.MAX - amount:
        return Int.MAX
    if amount < 0 and value < Int.MIN - amount:
        return Int.MIN
    return value + amount


def _extent_from(origin: Int, extent: Int) -> Int:
    """Clamp an extent so its exclusive end remains representable."""
    var safe_extent = _nonnegative(extent)
    if origin > 0:
        return _minimum(safe_extent, Int.MAX - origin)
    return safe_extent


def _saturating_distance(low: Int, high: Int) -> Int:
    if high <= low:
        return 0
    if low < 0 and high > Int.MAX + low:
        return Int.MAX
    return high - low


struct Point(Copyable):
    """A signed terminal-space coordinate."""

    var x: Int
    var y: Int

    def __init__(out self, x: Int = 0, y: Int = 0):
        self.x = x
        self.y = y

    def translated(self, dx: Int, dy: Int) -> Self:
        return Self(_saturating_add(self.x, dx), _saturating_add(self.y, dy))

    def equals(self, other: Self) -> Bool:
        return self.x == other.x and self.y == other.y


struct Size(Copyable):
    """A nonnegative terminal-space extent."""

    var width: Int
    var height: Int

    def __init__(out self, width: Int = 0, height: Int = 0):
        self.width = _nonnegative(width)
        self.height = _nonnegative(height)

    def is_empty(self) -> Bool:
        return self.width == 0 or self.height == 0

    def area(self) raises -> Int:
        if self.width != 0 and self.height > Int.MAX // self.width:
            raise Error("size area exceeds Int.MAX")
        return self.width * self.height

    def equals(self, other: Self) -> Bool:
        return self.width == other.width and self.height == other.height


struct Rect(Copyable):
    """A half-open signed rectangle whose dimensions are never negative."""

    var x: Int
    var y: Int
    var width: Int
    var height: Int

    def __init__(out self, x: Int = 0, y: Int = 0, width: Int = 0, height: Int = 0):
        self.x = x
        self.y = y
        self.width = _extent_from(x, width)
        self.height = _extent_from(y, height)

    @staticmethod
    def from_size(size: Size) -> Self:
        return Self(0, 0, size.width, size.height)

    def size(self) -> Size:
        return Size(self.width, self.height)

    def is_empty(self) -> Bool:
        return self.width == 0 or self.height == 0

    def area(self) raises -> Int:
        return self.size().area()

    def right(self) -> Int:
        return _saturating_add_nonnegative(self.x, self.width)

    def bottom(self) -> Int:
        return _saturating_add_nonnegative(self.y, self.height)

    def contains(self, point: Point) -> Bool:
        return (
            point.x >= self.x
            and point.x < self.right()
            and point.y >= self.y
            and point.y < self.bottom()
        )

    def intersects(self, other: Self) -> Bool:
        return not (
            self.is_empty()
            or other.is_empty()
            or self.right() <= other.x
            or other.right() <= self.x
            or self.bottom() <= other.y
            or other.bottom() <= self.y
        )

    def intersection(self, other: Self) -> Self:
        var left = _maximum(self.x, other.x)
        var top = _maximum(self.y, other.y)
        var right = _minimum(self.right(), other.right())
        var bottom = _minimum(self.bottom(), other.bottom())
        if right <= left or bottom <= top:
            return Self(left, top, 0, 0)
        return Self(left, top, right - left, bottom - top)

    def inset(self, horizontal: Int, vertical: Int) -> Self:
        var safe_horizontal = _nonnegative(horizontal)
        var safe_vertical = _nonnegative(vertical)
        var inset_width = _minimum(safe_horizontal, self.width // 2)
        var inset_height = _minimum(safe_vertical, self.height // 2)
        return Self(
            _saturating_add_nonnegative(self.x, inset_width),
            _saturating_add_nonnegative(self.y, inset_height),
            self.width - inset_width * 2,
            self.height - inset_height * 2,
        )

    def centered(self, width: Int, height: Int) -> Self:
        """Center clamped extents within this rectangle."""
        if self.is_empty():
            return Self(self.x, self.y, 0, 0)
        var centered_width = max(0, min(width, self.width))
        var centered_height = max(0, min(height, self.height))
        return Self(
            self.x + (self.width - centered_width) // 2,
            self.y + (self.height - centered_height) // 2,
            centered_width,
            centered_height,
        )

    def translated(self, dx: Int, dy: Int) -> Self:
        return Self(
            _saturating_add(self.x, dx),
            _saturating_add(self.y, dy),
            self.width,
            self.height,
        )

    def union(self, other: Self) -> Self:
        if self.is_empty():
            return other.copy()
        if other.is_empty():
            return self.copy()
        var left = _minimum(self.x, other.x)
        var top = _minimum(self.y, other.y)
        var right = _maximum(self.right(), other.right())
        var bottom = _maximum(self.bottom(), other.bottom())
        return Self(
            left,
            top,
            _saturating_distance(left, right),
            _saturating_distance(top, bottom),
        )

    def equals(self, other: Self) -> Bool:
        return (
            self.x == other.x
            and self.y == other.y
            and self.width == other.width
            and self.height == other.height
        )
