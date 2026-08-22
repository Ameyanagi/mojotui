from mojotui import Point, Rect
from std.testing import assert_true


def main() raises:
    assert_true(Rect(2, 3, 4, 2).contains(Point(5, 4)))
