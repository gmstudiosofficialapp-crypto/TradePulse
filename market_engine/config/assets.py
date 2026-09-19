from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class AssetConfig:
    symbol: str
    category: str
    enabled: bool
    base_price: float
    volatility: float
    trend_bias: float
    mean_reversion: float
    min_tick: float
    precision: int
    tick_interval_ms: int
    max_move_pct: float
    session: str
    seed: int


def _cfg(
    symbol: str,
    category: str,
    base: float,
    *,
    vol: float,
    trend: float,
    rev: float,
    tick: float,
    precision: int,
    seed: int,
    max_move: float = 0.0025,
) -> AssetConfig:
    return AssetConfig(
        symbol=symbol,
        category=category,
        enabled=True,
        base_price=base,
        volatility=vol,
        trend_bias=trend,
        mean_reversion=rev,
        min_tick=tick,
        precision=precision,
        tick_interval_ms=400,
        max_move_pct=max_move,
        session="always_on",
        seed=seed,
    )


ASSET_CONFIGS: dict[str, AssetConfig] = {
    "BTC/USD-OTC": _cfg("BTC/USD-OTC", "crypto", 67245.0, vol=0.0011, trend=0.00002, rev=0.04, tick=0.01, precision=2, seed=101),
    "ETH/USD-OTC": _cfg("ETH/USD-OTC", "crypto", 3248.5, vol=0.0013, trend=0.00001, rev=0.045, tick=0.01, precision=2, seed=102),
    "SOL/USD-OTC": _cfg("SOL/USD-OTC", "crypto", 148.32, vol=0.0018, trend=0.00003, rev=0.05, tick=0.01, precision=2, seed=103),
    "XRP/USD-OTC": _cfg("XRP/USD-OTC", "crypto", 0.6248, vol=0.002, trend=0.0, rev=0.06, tick=0.0001, precision=4, seed=104),
    "DOGE/USD-OTC": _cfg("DOGE/USD-OTC", "crypto", 0.14235, vol=0.0024, trend=0.00002, rev=0.055, tick=0.00001, precision=5, seed=105),
    "EUR/USD-OTC": _cfg("EUR/USD-OTC", "forex", 1.08542, vol=0.00035, trend=0.0, rev=0.08, tick=0.00001, precision=5, seed=201),
    "GBP/USD-OTC": _cfg("GBP/USD-OTC", "forex", 1.27186, vol=0.0004, trend=0.00001, rev=0.075, tick=0.00001, precision=5, seed=202),
    "USD/JPY-OTC": _cfg("USD/JPY-OTC", "forex", 149.248, vol=0.00038, trend=0.00001, rev=0.07, tick=0.001, precision=3, seed=203),
    "AUD/USD-OTC": _cfg("AUD/USD-OTC", "forex", 0.66214, vol=0.00042, trend=0.0, rev=0.08, tick=0.00001, precision=5, seed=204),
    "USD/CAD-OTC": _cfg("USD/CAD-OTC", "forex", 1.36108, vol=0.00036, trend=0.0, rev=0.08, tick=0.00001, precision=5, seed=205),
    "USD/CHF-OTC": _cfg("USD/CHF-OTC", "forex", 0.87842, vol=0.00034, trend=0.0, rev=0.08, tick=0.00001, precision=5, seed=206),
    "EUR/GBP-OTC": _cfg("EUR/GBP-OTC", "forex", 0.85326, vol=0.00032, trend=0.0, rev=0.085, tick=0.00001, precision=5, seed=207),
    "EUR/JPY-OTC": _cfg("EUR/JPY-OTC", "forex", 162.084, vol=0.0004, trend=0.00001, rev=0.07, tick=0.001, precision=3, seed=208),
    "GBP/JPY-OTC": _cfg("GBP/JPY-OTC", "forex", 189.762, vol=0.00045, trend=0.00001, rev=0.065, tick=0.001, precision=3, seed=209),
    "AUD/JPY-OTC": _cfg("AUD/JPY-OTC", "forex", 98.846, vol=0.00044, trend=0.0, rev=0.07, tick=0.001, precision=3, seed=210),
    "GOLD/USD-OTC": _cfg("GOLD/USD-OTC", "commodities", 2324.80, vol=0.0007, trend=0.00001, rev=0.05, tick=0.01, precision=2, seed=301),
    "SILVER/USD-OTC": _cfg("SILVER/USD-OTC", "commodities", 27.42, vol=0.0009, trend=0.0, rev=0.05, tick=0.001, precision=3, seed=302),
    "NASDAQ-OTC": _cfg("NASDAQ-OTC", "indices", 18246.0, vol=0.00055, trend=0.00001, rev=0.04, tick=0.25, precision=2, seed=401),
    "S&P500-OTC": _cfg("S&P500-OTC", "indices", 5482.4, vol=0.0005, trend=0.00001, rev=0.045, tick=0.05, precision=2, seed=402),
    "DOW JONES-OTC": _cfg("DOW JONES-OTC", "indices", 39852.0, vol=0.00048, trend=0.0, rev=0.04, tick=1.0, precision=2, seed=403),
}


def enabled_assets() -> list[AssetConfig]:
    return [cfg for cfg in ASSET_CONFIGS.values() if cfg.enabled]
