from mojotui import HighlightSpacing, List, ListItem


def main():
    _ = List([ListItem.from_text("item")], highlight_spacing=1)
