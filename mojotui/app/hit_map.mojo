"""Frame-local clipped interaction regions."""

from std.collections import List, Optional

from ..core.geometry import Point, Rect


struct Hit(Copyable):
    """The topmost registered region at a terminal cell."""

    var id: String
    var point: Point
    var local: Point

    def __init__(out self, var id: String, point: Point, local: Point):
        self.id = id^
        self.point = point.copy()
        self.local = local.copy()


struct _HitRegion(Copyable):
    var id: String
    var area: Rect
    var z_index: Int

    def __init__(out self, var id: String, area: Rect, z_index: Int):
        self.id = id^
        self.area = area.copy()
        self.z_index = z_index


struct HitMap(Copyable):
    """Interaction geometry rebuilt for every rendered frame."""

    var frame: Rect
    var clips: List[Rect]
    var regions: List[_HitRegion]

    def __init__(out self, frame: Rect):
        self.frame = frame.copy()
        self.clips = [frame.copy()]
        self.regions = List[_HitRegion]()

    def reset(mut self, frame: Rect):
        self.frame = frame.copy()
        self.clips = [frame.copy()]
        self.regions.clear()

    def current_clip(self) -> Rect:
        return self.clips[len(self.clips) - 1].copy()

    def push_clip(mut self, area: Rect):
        self.clips.append(self.current_clip().intersection(area))

    def pop_clip(mut self) -> Bool:
        if len(self.clips) <= 1:
            return False
        _ = self.clips.pop()
        return True

    def register(mut self, var id: String, area: Rect, z_index: Int = 0) -> Bool:
        """Register the currently visible portion of one interaction region."""
        if id == "":
            return False
        var clipped = self.current_clip().intersection(area)
        if clipped.is_empty():
            return False
        self.regions.append(_HitRegion(id^, clipped, z_index))
        return True

    def hit(self, point: Point) -> Optional[Hit]:
        """Resolve highest z-index; later registration wins equal-z ties."""
        var best = -1
        var best_z = Int.MIN
        for index in range(len(self.regions)):
            if (
                self.regions[index].area.contains(point)
                and self.regions[index].z_index >= best_z
            ):
                best = index
                best_z = self.regions[index].z_index
        if best < 0:
            return None
        var region = self.regions[best].copy()
        return Hit(
            region.id,
            point,
            Point(point.x - region.area.x, point.y - region.area.y),
        )

    def region_count(self) -> Int:
        return len(self.regions)
