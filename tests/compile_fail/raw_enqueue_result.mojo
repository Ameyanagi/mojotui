from mojotui import EnqueueResult


def consume_result(result: EnqueueResult):
    _ = result


def main():
    consume_result(0)
