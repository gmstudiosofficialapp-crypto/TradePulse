import asyncio
from datetime import datetime, timedelta, timezone

from app.services.coordinator import Phase3Coordinator, _trade_due_at
from app.services.demo_trading import DemoTradingEngine
from signal_engine.services.engine import SignalEngine

ASSET = "BTC/USD-OTC"
ENTRY = datetime(2026, 1, 1, 12, 0, 40, tzinfo=timezone.utc)


class _Quote:
    def __init__(self, price: float) -> None:
        self.price = price


class _Market:
    def __init__(self) -> None:
        self.quotes = {ASSET: _Quote(100.0)}


def _open_minute_trade(expiry_time: datetime | None = None) -> tuple[Phase3Coordinator, dict]:
    trading = DemoTradingEngine()
    coord = Phase3Coordinator(_Market(), SignalEngine(), trading)
    trade = trading.open_trade(
        "alice",
        ASSET,
        "BUY",
        10,
        100,
        now=ENTRY,
        expiry_seconds=60,
    )
    if expiry_time is not None:
        trade["expiry_time"] = expiry_time.isoformat()
        trading._hot_open[trade["trade_id"]]["expiry_time"] = trade["expiry_time"]
    return coord, trade


def test_one_minute_trade_does_not_close_at_candle_boundary() -> None:
    coord, trade = _open_minute_trade(expiry_time=datetime(2026, 1, 1, 12, 1, 0, tzinfo=timezone.utc))
    assert _trade_due_at(trade) == ENTRY + timedelta(seconds=60)

    asyncio.run(coord._settle_due(datetime(2026, 1, 1, 12, 1, 0, tzinfo=timezone.utc)))
    open_rows = coord.trading.open_snapshot()
    assert open_rows[0]["trade_id"] == trade["trade_id"]
    assert open_rows[0]["status"] == "OPEN"

    asyncio.run(coord._settle_due(datetime(2026, 1, 1, 12, 1, 40, tzinfo=timezone.utc)))
    assert coord.trading.open_snapshot() == []
    closed = coord.trading.trades.get(trade["trade_id"])
    assert closed is not None
    assert closed["status"] == "CLOSED"


def test_every_expiry_option_waits_for_its_own_duration() -> None:
    for seconds in (5, 15, 30, 60, 300, 900):
        trading = DemoTradingEngine()
        coord = Phase3Coordinator(_Market(), SignalEngine(), trading)
        trade = trading.open_trade(
            "alice",
            ASSET,
            "BUY",
            10,
            100,
            now=ENTRY,
            expiry_seconds=seconds,
        )
        due = ENTRY + timedelta(seconds=seconds)
        assert _trade_due_at(trade) == due

        asyncio.run(coord._settle_due(due - timedelta(seconds=1)))
        assert coord.trading.open_snapshot()[0]["trade_id"] == trade["trade_id"]

        candle_close = ENTRY.replace(second=0, microsecond=0) + timedelta(minutes=1)
        if candle_close < due:
            asyncio.run(coord._settle_due(candle_close))
            assert coord.trading.open_snapshot()[0]["trade_id"] == trade["trade_id"]

        asyncio.run(coord._settle_due(due))
        assert coord.trading.open_snapshot() == []
        closed = coord.trading.trades.get(trade["trade_id"])
        assert closed is not None
        assert closed["status"] == "CLOSED"
        assert closed["expiry_seconds"] == seconds


def test_future_tick_cannot_close_a_trade_early(monkeypatch) -> None:
    coord, trade = _open_minute_trade()
    monkeypatch.setattr(
        "app.services.coordinator._wall_clock",
        lambda: ENTRY + timedelta(seconds=20),
    )
    asyncio.run(coord._settle_due(ENTRY + timedelta(seconds=90)))
    assert coord.trading.open_snapshot()[0]["trade_id"] == trade["trade_id"]
