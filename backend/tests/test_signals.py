from datetime import datetime, timezone

from signal_engine.config.settings import SignalSettings
from signal_engine.services.engine import SignalEngine
from signal_engine.strategies.momentum import MomentumStrategy

from tests.helpers import trend_candles


class ForcedStrategy:
    def __init__(self, direction: str, confidence: float = 0.9) -> None:
        self.direction = direction
        self.confidence = confidence

    def analyze(self, candles, settings):
        return self.direction, self.confidence

    def generateSignal(self, candles, settings):
        return self.analyze(candles, settings)


def test_signal_generation_default_no_signal() -> None:
    engine = SignalEngine()
    signal = engine.analyze_closed("BTC/USD-OTC", [])
    assert signal.direction == "NO_SIGNAL"


def test_buy_signal() -> None:
    engine = SignalEngine(strategy=ForcedStrategy("BUY"))
    candles = trend_candles("BTC/USD-OTC", 100, 1)
    signal = engine.analyze_closed("BTC/USD-OTC", candles)
    assert signal.direction == "BUY"
    assert signal.entry_price == candles[-1].close
    assert signal.status == "ACTIVE"


def test_sell_signal() -> None:
    engine = SignalEngine(strategy=ForcedStrategy("SELL"))
    candles = trend_candles("ETH/USD-OTC", 200, -1)
    signal = engine.analyze_closed("ETH/USD-OTC", candles)
    assert signal.direction == "SELL"


def test_no_signal_from_choppy_market() -> None:
    engine = SignalEngine(strategy=MomentumStrategy(), settings=SignalSettings())
    candles = trend_candles("EUR/USD-OTC", 1.1, 0.0)
    signal = engine.analyze_closed("EUR/USD-OTC", candles)
    assert signal.direction == "NO_SIGNAL"


def test_signal_uniqueness_per_closed_candle() -> None:
    engine = SignalEngine(strategy=ForcedStrategy("BUY"))
    candles = trend_candles("BTC/USD-OTC", 100, 1)
    first = engine.analyze_closed("BTC/USD-OTC", candles)
    second = engine.analyze_closed("BTC/USD-OTC", candles)
    assert first.signal_id == second.signal_id


def test_signal_expiry_settlement() -> None:
    engine = SignalEngine(strategy=ForcedStrategy("BUY"))
    candles = trend_candles("BTC/USD-OTC", 100, 1)
    signal = engine.analyze_closed(
        "BTC/USD-OTC",
        candles,
        now=datetime(2026, 1, 1, 12, 10, tzinfo=timezone.utc),
    )
    settled = engine.settle(signal.signal_id, candles[-1].close + 5)
    assert settled.result == "WIN"
    assert settled.status == "CLOSED"
    assert settled.close_price == candles[-1].close + 5
    again = engine.settle(signal.signal_id, candles[-1].close - 5)
    assert again.result == "WIN"
    assert again.status == "CLOSED"


def test_ten_independent_active_signals_and_capacity() -> None:
    engine = SignalEngine(strategy=ForcedStrategy("BUY"))
    created = []
    for index in range(12):
        candles = trend_candles("BTC/USD-OTC", 100 + index, 1, count=8 + index)
        created.append(engine.analyze_closed("BTC/USD-OTC", candles))
    active = engine.active_for("BTC/USD-OTC")
    assert len(active) == 10
    assert len({item.signal_id for item in active}) == 10
    assert created[10].direction == "NO_SIGNAL"
    assert created[11].direction == "NO_SIGNAL"
    closed = engine.settle(active[0].signal_id, active[0].entry_price + 1)
    assert closed.status == "CLOSED"
    assert len(engine.active_for("BTC/USD-OTC")) == 9
    nxt = trend_candles("BTC/USD-OTC", 200, 1, count=30)
    extra = engine.analyze_closed("BTC/USD-OTC", nxt)
    assert extra.direction == "BUY"
    assert extra.signal_id != closed.signal_id
    assert len(engine.active_for("BTC/USD-OTC")) == 10


def test_opposite_direction_does_not_overwrite() -> None:
    buy_engine = SignalEngine(strategy=ForcedStrategy("BUY"))
    first = buy_engine.analyze_closed("BTC/USD-OTC", trend_candles("BTC/USD-OTC", 100, 1))
    buy_engine.strategy = ForcedStrategy("SELL")
    second = buy_engine.analyze_closed("BTC/USD-OTC", trend_candles("BTC/USD-OTC", 110, -1, count=14))
    assert first.signal_id != second.signal_id
    assert first.direction == "BUY"
    assert second.direction == "SELL"
    assert first.status == "ACTIVE"
    assert {item.signal_id for item in buy_engine.active_for("BTC/USD-OTC")} == {
        first.signal_id,
        second.signal_id,
    }
    buy_engine.settle(second.signal_id, second.entry_price + 1)
    leftover = buy_engine.active_for("BTC/USD-OTC")
    assert [item.signal_id for item in leftover] == [first.signal_id]
    assert leftover[0].direction == "BUY"

