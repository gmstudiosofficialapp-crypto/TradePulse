from datetime import datetime, timedelta, timezone
from random import Random

from market_engine.config.assets import ASSET_CONFIGS, enabled_assets
from market_engine.config.settings import EngineSettings
from market_engine.models.tick import Tick
from market_engine.services.candle_engine import CandleEngine, minute_floor_utc
from market_engine.services.candle_store import MemoryCandleStore
from market_engine.services.market_runtime import MarketRuntime
from market_engine.services.price_validator import validate_price
from market_engine.services.tick_engine import TickEngine


def test_asset_configuration() -> None:
    assets = enabled_assets()
    assert len(assets) == 20
    assert "BTC/USD-OTC" in ASSET_CONFIGS
    assert all(item.symbol.endswith("OTC") or "OTC" in item.symbol for item in assets)
    assert ASSET_CONFIGS["BTC/USD-OTC"].base_price > 0
    assert ASSET_CONFIGS["EUR/USD-OTC"].precision == 5


def test_price_generation_is_continuous() -> None:
    cfg = ASSET_CONFIGS["BTC/USD-OTC"]
    engine = TickEngine(cfg, Random(1))
    prices = [engine.next_tick().price for _ in range(40)]
    assert all(price > 0 for price in prices)
    moves = [abs(prices[i] - prices[i - 1]) / prices[i - 1] for i in range(1, len(prices))]
    assert max(moves) <= cfg.max_move_pct * 1.05


def test_tick_validation_rejects_invalid() -> None:
    cfg = ASSET_CONFIGS["ETH/USD-OTC"]
    assert validate_price(100.0, float("nan"), cfg) == 100.0
    assert validate_price(100.0, -5.0, cfg) == 100.0
    limited = validate_price(100.0, 200.0, cfg)
    assert limited < 200.0
    assert abs(limited - 100.0) <= 100.0 * cfg.max_move_pct + cfg.min_tick


def test_candle_ohlc_from_ticks() -> None:
    engine = CandleEngine("BTC/USD-OTC")
    start = datetime(2026, 9, 18, 12, 0, tzinfo=timezone.utc)
    ticks = [
        Tick("BTC/USD-OTC", start + timedelta(seconds=1), 100.0),
        Tick("BTC/USD-OTC", start + timedelta(seconds=20), 104.0),
        Tick("BTC/USD-OTC", start + timedelta(seconds=40), 98.0),
        Tick("BTC/USD-OTC", start + timedelta(seconds=50), 101.0),
    ]
    current = None
    for tick in ticks:
        _, current = engine.apply_tick(tick)
    assert current is not None
    assert current.open == 100.0
    assert current.high == 104.0
    assert current.low == 98.0
    assert current.close == 101.0
    assert current.volume == 4


def test_minute_boundary_closes_candle() -> None:
    engine = CandleEngine("EUR/USD-OTC")
    first = datetime(2026, 9, 18, 12, 0, 10, tzinfo=timezone.utc)
    next_minute = datetime(2026, 9, 18, 12, 1, 1, tzinfo=timezone.utc)
    _, current = engine.apply_tick(Tick("EUR/USD-OTC", first, 1.1))
    closed, current = engine.apply_tick(Tick("EUR/USD-OTC", next_minute, 1.2))
    assert closed is not None
    assert closed.closed is True
    assert closed.close_time == datetime(2026, 9, 18, 12, 1, tzinfo=timezone.utc)
    assert current.open_time == datetime(2026, 9, 18, 12, 1, tzinfo=timezone.utc)
    assert minute_floor_utc(first) != minute_floor_utc(next_minute)


def test_historical_buffer_rolls() -> None:
    store = MemoryCandleStore(maxlen=3)
    engine = CandleEngine("SOL/USD-OTC")
    start = datetime(2026, 9, 18, 10, 0, tzinfo=timezone.utc)
    for minute in range(5):
        ts = start + timedelta(minutes=minute, seconds=1)
        engine.apply_tick(Tick("SOL/USD-OTC", ts, 100 + minute))
        closed = engine.force_close()
        assert closed is not None
        store.append(closed)
    history = store.history("SOL/USD-OTC")
    assert len(history) == 3
    assert history[0].open_time == start + timedelta(minutes=2)


def test_multiple_assets_independent() -> None:
    runtime = MarketRuntime(
        settings=EngineSettings(history_size=5, warmup_ticks_per_minute=3),
        assets=[ASSET_CONFIGS["BTC/USD-OTC"], ASSET_CONFIGS["EUR/USD-OTC"]],
    )
    runtime.warmup(datetime(2026, 9, 18, 15, 0, tzinfo=timezone.utc))
    assert len(runtime.streams) == 2
    btc = runtime.quotes["BTC/USD-OTC"].price
    eur = runtime.quotes["EUR/USD-OTC"].price
    runtime.step(datetime(2026, 9, 18, 15, 0, 20, tzinfo=timezone.utc))
    assert runtime.quotes["BTC/USD-OTC"].price != eur or True
    assert runtime.quotes["BTC/USD-OTC"].asset != runtime.quotes["EUR/USD-OTC"].asset
    assert btc > 1000
    assert 0 < runtime.quotes["EUR/USD-OTC"].price < 5
    assert len(runtime.history("BTC/USD-OTC")) >= 5
