from datetime import datetime, timedelta, timezone

from market_engine.models.candle import Candle


def closed_candle(
    asset: str,
    close: float,
    *,
    open_: float | None = None,
    high: float | None = None,
    low: float | None = None,
    minute: datetime | None = None,
) -> Candle:
    open_time = minute or datetime(2026, 1, 1, 12, 0, tzinfo=timezone.utc)
    open_px = open_ if open_ is not None else close
    return Candle(
        asset=asset,
        timeframe="1m",
        open_time=open_time,
        close_time=open_time + timedelta(minutes=1),
        open=open_px,
        high=high if high is not None else max(open_px, close),
        low=low if low is not None else min(open_px, close),
        close=close,
        volume=8,
        closed=True,
    )


def trend_candles(asset: str, start: float, step: float, count: int = 10) -> list[Candle]:
    base = datetime(2026, 1, 1, 12, 0, tzinfo=timezone.utc)
    candles = []
    price = start
    for index in range(count):
        nxt = price + step
        candles.append(
            closed_candle(
                asset,
                nxt,
                open_=price,
                minute=base + timedelta(minutes=index),
            )
        )
        price = nxt
    return candles
