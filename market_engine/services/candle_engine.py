from __future__ import annotations

from datetime import datetime, timedelta, timezone

from market_engine.models.candle import Candle
from market_engine.models.tick import Tick


def minute_floor_utc(ts: datetime) -> datetime:
    if ts.tzinfo is None:
        ts = ts.replace(tzinfo=timezone.utc)
    else:
        ts = ts.astimezone(timezone.utc)
    return ts.replace(second=0, microsecond=0)


def minute_close_utc(open_time: datetime) -> datetime:
    return minute_floor_utc(open_time) + timedelta(minutes=1)


class CandleEngine:
    def __init__(self, asset: str, timeframe: str = "1m") -> None:
        self.asset = asset
        self.timeframe = timeframe
        self.current: Candle | None = None

    def apply_tick(self, tick: Tick) -> tuple[Candle | None, Candle]:
        open_time = minute_floor_utc(tick.timestamp)
        if self.current is None:
            self.current = self._new_candle(tick, open_time)
            return None, self.current
        if open_time > self.current.open_time:
            closed = self._close(self.current)
            self.current = self._new_candle(tick, open_time)
            return closed, self.current
        candle = self.current
        candle.high = max(candle.high, tick.price)
        candle.low = min(candle.low, tick.price)
        candle.close = tick.price
        candle.volume += 1
        candle.close_time = tick.timestamp
        return None, candle

    def force_close(self, close_time: datetime | None = None) -> Candle | None:
        if self.current is None or self.current.closed:
            return None
        if close_time is not None:
            self.current.close_time = close_time
        closed = self._close(self.current)
        self.current = None
        return closed

    def _new_candle(self, tick: Tick, open_time: datetime) -> Candle:
        return Candle(
            asset=self.asset,
            timeframe=self.timeframe,
            open=tick.price,
            high=tick.price,
            low=tick.price,
            close=tick.price,
            volume=1,
            open_time=open_time,
            close_time=tick.timestamp,
            closed=False,
        )

    def _close(self, candle: Candle) -> Candle:
        candle.closed = True
        candle.close_time = minute_close_utc(candle.open_time)
        return candle
