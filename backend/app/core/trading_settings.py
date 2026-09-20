from dataclasses import dataclass


ALLOWED_EXPIRY_SECONDS = (5, 15, 30, 60, 300, 900)

# 10 × 92%, 2 × 90%, 5 × 85%, 3 × 80%
ASSET_PAYOUT_RATES: dict[str, float] = {
    "BTC/USD-OTC": 0.92,
    "ETH/USD-OTC": 0.92,
    "SOL/USD-OTC": 0.92,
    "EUR/USD-OTC": 0.92,
    "GBP/USD-OTC": 0.92,
    "USD/JPY-OTC": 0.92,
    "GOLD/USD-OTC": 0.92,
    "NASDAQ-OTC": 0.92,
    "S&P500-OTC": 0.92,
    "EUR/JPY-OTC": 0.92,
    "XRP/USD-OTC": 0.90,
    "GBP/JPY-OTC": 0.90,
    "DOGE/USD-OTC": 0.85,
    "AUD/USD-OTC": 0.85,
    "USD/CAD-OTC": 0.85,
    "SILVER/USD-OTC": 0.85,
    "EUR/GBP-OTC": 0.85,
    "USD/CHF-OTC": 0.80,
    "AUD/JPY-OTC": 0.80,
    "DOW JONES-OTC": 0.80,
}


def payout_rate_for(asset: str, default: float = 0.85) -> float:
    return ASSET_PAYOUT_RATES.get(asset, default)


@dataclass(frozen=True, slots=True)
class TradingSettings:
    initial_balance: float = 10000.0
    payout_rate: float = 0.85
    expiry_seconds: int = 60
    min_stake: float = 1.0
    max_stake: float = 10000.0
    max_open_trades_per_asset: int = 10
    allowed_expiry_seconds: tuple[int, ...] = ALLOWED_EXPIRY_SECONDS
