from dataclasses import dataclass


ALLOWED_EXPIRY_SECONDS = (5, 15, 30, 60, 300, 900)


@dataclass(frozen=True, slots=True)
class TradingSettings:
    initial_balance: float = 10000.0
    payout_rate: float = 0.85
    expiry_seconds: int = 60
    min_stake: float = 1.0
    max_stake: float = 10000.0
    max_open_trades_per_asset: int = 10
    allowed_expiry_seconds: tuple[int, ...] = ALLOWED_EXPIRY_SECONDS
