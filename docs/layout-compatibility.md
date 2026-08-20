# Ratatui layout compatibility

Mojotui's shared layout contract uses Ratatui `0.30.2` behavior as its target.
The initial corpus was generated from the later development commit
`31809ba9d49df614f510254a124ea027a8be19f9` dated 2026-08-16, not from the
published `ratatui-v0.30.2` tag (which peels to
`e665c36cb14752a61cd777fbd06dbef8474f2add`). The inspected layout diff contains
documentation and iterator-refactoring changes but no identified observable
allocation change. Stage I will regenerate the corpus from the published tag
and record the generator version and checksum so this distinction is
machine-auditable. Ratatui remains a development input, not a vendored
dependency.

## Shared behavior

The following behavior is intended to match Ratatui's non-legacy `Layout`:

- horizontal and vertical splits;
- `Length`, `Min`, `Max`, `Percentage`, `Ratio`, and weighted `Fill`
  constraints, including zero fill weights and ratios or percentages above one
  whole;
- over-constraint priority: `Min`, `Max`, `Length`, `Percentage`, `Ratio`, then
  `Fill`;
- `Start`, `Center`, `End`, `SpaceBetween`, `SpaceEvenly`, and `SpaceAround`;
- nonnegative spacing and symmetric horizontal/vertical margins;
- integer rounding that keeps every result contained and deterministic.

The checked fixtures in `tests/test_layout.mojo` include the following Ratatui
0.30.2 cases (ranges are horizontal positions in a 100-column area):

| Constraints | Flex / spacing | Expected ranges |
| --- | --- | --- |
| `Length(25), Length(25)` | `Start` | `0..25, 25..50` |
| `Length(25), Length(25)` | `Center` | `25..50, 50..75` |
| `Length(25), Length(25)` | `End` | `50..75, 75..100` |
| `Length(25), Length(25)` | `SpaceBetween` | `0..25, 75..100` |
| `Length(25), Length(25)` | `SpaceEvenly` | `17..42, 58..83` |
| `Length(25), Length(25)` | `SpaceAround` | `13..38, 63..88` |
| `Max(25), Max(25)` | `SpaceAround` | `13..38, 63..88` |
| `Percentage(25), Percentage(25)` | `SpaceEvenly` | `17..42, 58..83` |
| `Min(25), Min(25)` | `Start` | `0..50, 50..100` |
| `Length(4), Length(4)` | `Start`, spacing 1, width 4 | `0..2, 3..4` |
| `Length(100), Length(1), Min(20)` | `Start` | `0..79, 79..80, 80..100` |

Property-style sweeps exercise every supported flex mode from zero through 128
columns and assert containment, ordering, and nonnegative geometry.

## Deliberate differences

- Ratatui's `Flex::Legacy` is not exposed. Mojotui defaults to `Flex.START` and
  does not place all excess into the lowest-priority final segment.
- Negative spacing / overlapping segments are not supported. Mojotui clamps
  spacing to zero so widget rectangles remain non-overlapping.
- `split_with_spacers` and Ratatui's optional global layout cache are not part of
  the current API. Caching waits for a Mojotui benchmark demonstrating value.
- Mojotui geometry uses signed `Int` coordinates with saturating containment,
  rather than Ratatui's `u16` coordinate domain.

These exclusions are not considered compatibility failures because their API
surface is not shared. Add any new shared behavior to the fixture corpus before
changing the allocator.
