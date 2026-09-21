from __future__ import annotations

import copy
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from random import Random

from market_engine.config.assets import AssetConfig
from market_engine.generators.price_generator import PriceGenerator
from market_engine.models.candle import Candle
from market_engine.models.tick import Tick
from market_engine.services.candle_engine import CandleEngine, minute_floor_utc
from market_engine.services.price_validator import validate_price

BTC_SYMBOL = "BTC/USD-OTC"


def _utc(ts: datetime) -> datetime:
    if ts.tzinfo is None:
        return ts.replace(tzinfo=timezone.utc)
    return ts.astimezone(timezone.utc)


def _direction(open_px: float, close_px: float) -> str:
    if close_px > open_px:
        return "UP"
    if close_px < open_px:
        return "DOWN"
    return "FLAT"


def clone_price_generator(live: PriceGenerator) -> PriceGenerator:
    cloned_rng = Random()
    cloned_rng.setstate(live.rng.getstate())
    cloned = PriceGenerator(live.config, cloned_rng)
    cloned.state = copy.deepcopy(live.state)
    return cloned


def emit_tick(generator: PriceGenerator, timestamp: datetime) -> Tick:
    raw = generator.next_raw_price()
    previous = generator.state.price
    price = validate_price(previous, raw, generator.config)
    generator.state.price = price
    return Tick(asset=generator.config.symbol, timestamp=_utc(timestamp), price=price)


@dataclass(slots=True)
class PrecomputedCandle:
    asset: str
    open_time: datetime
    close_time: datetime
    open: float
    high: float
    low: float
    close: float
    direction: str
    volume: int
    rng_state_after: object = field(repr=False, compare=False)
    price_state_after: object = field(repr=False, compare=False)

    def to_public(self) -> dict:
        return {
            "asset": self.asset,
            "candle_start_time": self.open_time.isoformat(),
            "candle_end_time": self.close_time.isoformat(),
            "open": self.open,
            "high": self.high,
            "low": self.low,
            "close": self.close,
            "direction": self.direction,
            "volume": self.volume,
            "timeframe": "1m",
            "precomputed": True,
            "simulated": True,
        }


def ticks_per_minute(interval_ms: int) -> int:
    return max(1, 60_000 // max(interval_ms, 1))


def tick_stamp(open_time: datetime, index: int, interval_ms: int) -> datetime:
    return _utc(open_time) + timedelta(milliseconds=max(interval_ms, 1) * index)


def ticks_in_minute(open_time: datetime, interval_ms: int) -> list[datetime]:
    open_time = minute_floor_utc(open_time)
    return [
        tick_stamp(open_time, index, interval_ms)
        for index in range(ticks_per_minute(interval_ms))
    ]


def remaining_ticks(live: Candle, interval_ms: int) -> list[datetime]:
    """Canonical leftover ticks this minute so total ticks stay 60_000/interval."""
    per = ticks_per_minute(interval_ms)
    used = min(per, max(0, int(live.volume)))
    open_time = minute_floor_utc(live.open_time)
    return [tick_stamp(open_time, index, interval_ms) for index in range(used, per)]


def due_live_stamps(
    live: Candle | None,
    now: datetime,
    interval_ms: int,
    limit: int | None = None,
) -> list[datetime]:
    """Authoritative BTC stamps whose grid time is due at `now`.

    Wall-clock jitter cannot skip or duplicate ticks: a late loop catches up
    onto the same 1m grid the future book simulates.
    """
    now = _utc(now)
    interval_ms = max(interval_ms, 1)
    per = ticks_per_minute(interval_ms)
    cap = per if limit is None else max(1, limit)
    wall_open = minute_floor_utc(now)
    if live is None:
        return [tick_stamp(wall_open, 0, interval_ms)]

    open_time = minute_floor_utc(live.open_time)
    index = min(per, max(0, int(live.volume)))
    stamps: list[datetime] = []
    while len(stamps) < cap:
        if open_time < wall_open:
            if index < per:
                stamps.append(tick_stamp(open_time, index, interval_ms))
                index += 1
                continue
            open_time = open_time + timedelta(minutes=1)
            index = 0
            continue
        elapsed_ms = (now - open_time).total_seconds() * 1000
        due_index = min(per, int(elapsed_ms // interval_ms) + 1)
        if index < due_index:
            stamps.append(tick_stamp(open_time, index, interval_ms))
            index += 1
            continue
        break
    return stamps


def apply_ticks(
    generator: PriceGenerator,
    candle_engine: CandleEngine,
    timestamps: list[datetime],
) -> Candle | None:
    current: Candle | None = candle_engine.current
    for stamp in timestamps:
        _closed, current = candle_engine.apply_tick(emit_tick(generator, stamp))
    return current


def snapshot_minute(current: Candle, open_time: datetime) -> Candle:
    return Candle(
        asset=current.asset,
        timeframe=current.timeframe,
        open=current.open,
        high=current.high,
        low=current.low,
        close=current.close,
        volume=current.volume,
        open_time=minute_floor_utc(open_time),
        close_time=minute_floor_utc(open_time) + timedelta(minutes=1),
        closed=True,
    )


class BtcFutureBook:
    """Rolling next-3 1m candles for BTC, simulated from a cloned RNG."""

    def __init__(self, horizon: int = 3) -> None:
        self.horizon = horizon
        self.live_open: datetime | None = None
        self.futures: list[PrecomputedCandle] = []

    def snapshot(self, live: Candle | None) -> dict:
        return {
            "asset": BTC_SYMBOL,
            "live": None
            if live is None
            else {
                "asset": live.asset,
                "candle_start_time": live.open_time.isoformat(),
                "candle_end_time": live.close_time.isoformat(),
                "open": live.open,
                "high": live.high,
                "low": live.low,
                "close": live.close,
                "direction": _direction(live.open, live.close),
                "closed": live.closed,
                "volume": live.volume,
                "timeframe": "1m",
            },
            "futures": [item.to_public() for item in self.futures],
            "future_count": len(self.futures),
            "rolling": True,
        }

    def sync(self, stream, now: datetime, closed: Candle | None = None) -> None:
        if stream.config.symbol != BTC_SYMBOL:
            return
        live = stream.candles.current
        live_open = minute_floor_utc(live.open_time if live else now)
        if closed is not None and self.futures and self._can_roll(closed):
            self._roll(stream, closed)
            return
        if (
            len(self.futures) == self.horizon
            and self.live_open == live_open
            and closed is None
        ):
            return
        self.rebuild(stream, now)

    def _can_roll(self, closed: Candle) -> bool:
        if len(self.futures) != self.horizon:
            return False
        expected = minute_floor_utc(closed.open_time) + timedelta(minutes=1)
        return minute_floor_utc(self.futures[0].open_time) == expected

    def _roll(self, stream, closed: Candle) -> None:
        self.live_open = minute_floor_utc(closed.open_time) + timedelta(minutes=1)
        self.futures = self.futures[1:]
        last = self.futures[-1]
        self.futures.append(
            self._simulate_minute(
                stream.config,
                last.rng_state_after,
                last.price_state_after,
                last.open_time + timedelta(minutes=1),
            )
        )

    def rebuild(self, stream, now: datetime) -> None:
        live = stream.candles.current
        if live is None:
            self.futures = []
            self.live_open = None
            return
        interval = max(stream.config.tick_interval_ms, 1)
        generator = clone_price_generator(stream.ticks.generator)
        engine = CandleEngine(BTC_SYMBOL)
        engine.current = copy.deepcopy(live)
        live_open = minute_floor_utc(live.open_time)
        apply_ticks(generator, engine, remaining_ticks(live, interval))
        futures: list[PrecomputedCandle] = []
        for index in range(1, self.horizon + 1):
            open_time = live_open + timedelta(minutes=index)
            current = apply_ticks(
                generator, engine, ticks_in_minute(open_time, interval)
            )
            if current is None or minute_floor_utc(current.open_time) != open_time:
                raise RuntimeError("Failed to precompute BTC future candle")
            frozen = snapshot_minute(current, open_time)
            futures.append(
                PrecomputedCandle(
                    asset=BTC_SYMBOL,
                    open_time=frozen.open_time,
                    close_time=frozen.close_time,
                    open=frozen.open,
                    high=frozen.high,
                    low=frozen.low,
                    close=frozen.close,
                    direction=_direction(frozen.open, frozen.close),
                    volume=int(frozen.volume),
                    rng_state_after=generator.rng.getstate(),
                    price_state_after=copy.deepcopy(generator.state),
                )
            )
        self.live_open = live_open
        self.futures = futures

    def _simulate_minute(
        self,
        config: AssetConfig,
        rng_state: object,
        price_state: object,
        open_time: datetime,
    ) -> PrecomputedCandle:
        rng = Random()
        rng.setstate(rng_state)
        generator = PriceGenerator(config, rng)
        generator.state = copy.deepcopy(price_state)
        engine = CandleEngine(BTC_SYMBOL)
        stamps = ticks_in_minute(open_time, max(config.tick_interval_ms, 1))
        current = apply_ticks(generator, engine, stamps)
        if current is None:
            raise RuntimeError("Failed to roll BTC future candle")
        frozen = snapshot_minute(current, open_time)
        return PrecomputedCandle(
            asset=BTC_SYMBOL,
            open_time=frozen.open_time,
            close_time=frozen.close_time,
            open=frozen.open,
            high=frozen.high,
            low=frozen.low,
            close=frozen.close,
            direction=_direction(frozen.open, frozen.close),
            volume=int(frozen.volume),
            rng_state_after=generator.rng.getstate(),
            price_state_after=copy.deepcopy(generator.state),
        )
