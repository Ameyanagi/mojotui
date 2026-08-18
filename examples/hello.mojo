from mojotui import Buffer, Line, Paragraph, Rect, Text


def main() raises:
    var area = Rect(0, 0, 24, 3)
    var frame = Buffer(area)
    var message = Paragraph(Text.from_line(Line.from_text("hello from Mojo")))
    message.render(area, frame)

    var first_row = String()
    for x in range(area.x, area.right()):
        var cell = frame.cell({x, area.y})
        if not cell.continuation:
            first_row += cell.symbol
    print(first_row)
