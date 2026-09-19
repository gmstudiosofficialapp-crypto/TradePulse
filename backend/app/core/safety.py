LIVE_TRADING_ENABLED = False


class LiveTradingDisabledError(RuntimeError):
    def __init__(self) -> None:
        super().__init__(
            "Live trading is permanently disabled. Demo simulation only."
        )


def reject_live_trade(*_args, **_kwargs) -> None:
    raise LiveTradingDisabledError()


def execute_live_trade(*_args, **_kwargs) -> None:
    """No broker, no live execution. Always rejected."""
    reject_live_trade()
