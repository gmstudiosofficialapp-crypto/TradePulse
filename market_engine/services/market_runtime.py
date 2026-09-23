from __future__ import annotations

import asyncio
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from random import Random

from market_engine.config.assets import ASSET_CONFIGS, AssetConfig, enabled_assets
from market_engine.config.settings import EngineSettings
from market_engine.models.candle import Candle
from market_engine.models.tick import Tick
from market_engine.services.btc_future_book import (
    BTC_SYMBOL,
    BtcFutureBook,
    due_live_stamps,
)
from market_engine.services.candle_engine import CandleEngine, minute_floor_utc
from market_engine.services.candle_store import CandleStore, MemoryCandleStore
from market_engine.services.tick_engine import TickEngine

TickHandler = Callable[[Tick, Candle, Candle | None], Awaitable[None] | None]


@dataclass(slots=True)
class MarketEvent:
    tick: Tick
    candle: Candle
    closed: Candle | None


class AssetStream:
    def __init__(self, config: AssetConfig, rng: Random) -> None:
        self.config = config
        self.ticks = TickEngine(config, rng)
        self.candles = CandleEngine(config.symbol)

    @property
    def price(self) -> float:
        return self.ticks.price


class MarketRuntime:
    def __init__(
        self,
        settings: EngineSettings | None = None,
        store: CandleStore | None = None,
        assets: list[AssetConfig] | None = None,
    ) -> None:
        self.settings = settings or EngineSettings()
        self.store = store or MemoryCandleStore(maxlen=self.settings.history_size)
        selected = assets or enabled_assets()
        self.streams: dict[str, AssetStream] = {
            cfg.symbol: AssetStream(cfg, Random(self.settings.seed + cfg.seed))
            for cfg in selected
        }
        self.running = False
        self._task: asyncio.Task[None] | None = None
        self._wake_lock: asyncio.Lock | None = None
        self._last_step_at: datetime | None = None
        self._handlers: list[TickHandler] = []
        self.quotes: dict[str, Tick] = {}
        self.open_candles: dict[str, Candle] = {}
        self.session_open: dict[str, float] = {}
        self.btc_future_book = BtcFutureBook()

    def add_handler(self, handler: TickHandler) -> None:
        if handler not in self._handlers:
            self._handlers.append(handler)

    def snapshot_quote(self, symbol: str) -> dict | None:
        tick = self.quotes.get(symbol)
        candle = self.open_candles.get(symbol)
        if tick is None:
            return None
        open_px = self.session_open.get(symbol, tick.price)
        change_pct = 0.0 if open_px == 0 else ((tick.price - open_px) / open_px) * 100
        return {
            "asset": symbol,
            "price": tick.price,
            "timestamp": tick.timestamp.isoformat(),
            "change_pct": round(change_pct, 4),
            "candle": candle.to_dict() if candle else None,
            "simulated": True,
        }

    def all_quotes(self) -> list[dict]:
        return [q for symbol in self.streams if (q := self.snapshot_quote(symbol))]

    def history(self, symbol: str, limit: int = 500) -> list[dict]:
        candles = self.store.history(symbol, limit=limit)
        current = self.open_candles.get(symbol)
        payload = [c.to_dict() for c in candles]
        if current is not None:
            payload.append(current.to_dict())
        return payload

    def warmup(self, now: datetime | None = None) -> None:
        moment = now or datetime.now(timezone.utc)
        if moment.tzinfo is None:
            moment = moment.replace(tzinfo=timezone.utc)
        else:
            moment = moment.astimezone(timezone.utc)
        live_open = minute_floor_utc(moment)
        start = live_open - timedelta(minutes=self.settings.history_size)
        ticks = max(2, self.settings.warmup_ticks_per_minute)
        for stream in self.streams.values():
            history: list[Candle] = []
            for index in range(self.settings.history_size):
                minute = start + timedelta(minutes=index)
                for step in range(ticks):
                    offset = timedelta(seconds=((step + 1) * 59 / ticks))
                    tick = stream.ticks.next_tick(minute + offset)
                    stream.candles.apply_tick(tick)
                closed = stream.candles.force_close(minute + timedelta(minutes=1))
                if closed is not None:
                    history.append(closed)
            self.store.replace(stream.config.symbol, history)
            if history:
                self.session_open[stream.config.symbol] = history[0].open
            seed_tick = stream.ticks.next_tick(live_open + timedelta(seconds=1))
            _, current = stream.candles.apply_tick(seed_tick)
            self.quotes[stream.config.symbol] = seed_tick
            self.open_candles[stream.config.symbol] = current
            self.session_open.setdefault(stream.config.symbol, seed_tick.price)
            if stream.config.symbol == BTC_SYMBOL:
                self.btc_future_book.sync(stream, moment)
        self._last_step_at = moment

    def btc_future_snapshot(self) -> dict:
        return self.btc_future_book.snapshot(self.open_candles.get(BTC_SYMBOL))

    def _advance(self, stream: AssetStream, timestamp: datetime) -> MarketEvent:
        tick = stream.ticks.next_tick(timestamp)
        closed, current = stream.candles.apply_tick(tick)
        if closed is not None:
            self.store.append(closed)
        self.quotes[stream.config.symbol] = tick
        self.open_candles[stream.config.symbol] = current
        self.session_open.setdefault(stream.config.symbol, tick.price)
        if stream.config.symbol == BTC_SYMBOL:
            self.btc_future_book.sync(stream, tick.timestamp, closed)
        return MarketEvent(tick=tick, candle=current, closed=closed)

    def step(self, timestamp: datetime | None = None) -> list[MarketEvent]:
        """Advance every stream to ``timestamp``.

        When ``timestamp`` is omitted the server's current UTC wall clock is
        read here. BTC catches up every missed minute in this call, so the
        live candle opens on ``floor(now, 1 minute)``.
        """
        now = timestamp or datetime.now(timezone.utc)
        if now.tzinfo is None:
            now = now.replace(tzinfo=timezone.utc)
        else:
            now = now.astimezone(timezone.utc)
        events: list[MarketEvent] = []
        for stream in self.streams.values():
            if stream.config.symbol == BTC_SYMBOL:
                stamps = due_live_stamps(
                    stream.candles.current,
                    now,
                    stream.config.tick_interval_ms,
                )
                for stamp in stamps:
                    events.append(self._advance(stream, stamp))
                continue
            events.append(self._advance(stream, now))
        if events:
            self._last_step_at = events[-1].tick.timestamp
        return events

    def _tick_interval_seconds(self) -> float:
        interval_ms = min(
            (stream.config.tick_interval_ms for stream in self.streams.values()),
            default=self.settings.default_tick_interval_ms,
        )
        return max(interval_ms / 1000, 0.05)

    def loop_alive(self) -> bool:
        return bool(self.running and self._task is not None and not self._task.done())

    def is_stale(self, now: datetime | None = None) -> bool:
        moment = now or datetime.now(timezone.utc)
        if moment.tzinfo is None:
            moment = moment.replace(tzinfo=timezone.utc)
        else:
            moment = moment.astimezone(timezone.utc)
        if not self.quotes:
            return True
        latest = self._last_step_at
        for tick in self.quotes.values():
            stamp = tick.timestamp
            if stamp.tzinfo is None:
                stamp = stamp.replace(tzinfo=timezone.utc)
            if latest is None or stamp > latest:
                latest = stamp
        if latest is None:
            return True
        max_age = max(2.0, self._tick_interval_seconds() * 5)
        return (moment - latest).total_seconds() > max_age

    async def ensure_awake(self, now: datetime | None = None) -> None:
        """Wake the single shared loop and reconcile wall-clock market state."""
        if self._wake_lock is None:
            self._wake_lock = asyncio.Lock()
        async with self._wake_lock:
            moment = now or datetime.now(timezone.utc)
            if self.is_stale(moment) or not self.quotes:
                if not self.quotes:
                    self.warmup(moment)
                self.step(moment)
            await self.start()

    async def start(self) -> None:
        if self.loop_alive():
            return
        if self._task is not None and not self._task.done():
            self.running = False
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
        self._task = None
        if not self.quotes:
            self.warmup()
        self.running = True
        self._task = asyncio.create_task(self._loop(), name="otc-market-loop")

    async def stop(self) -> None:
        self.running = False
        if self._task is not None:
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
            self._task = None

    async def _loop(self) -> None:
        interval = min(
            (stream.config.tick_interval_ms for stream in self.streams.values()),
            default=self.settings.default_tick_interval_ms,
        )
        delay = max(interval / 1000, 0.05)
        while self.running:
            # Read the clock on every pass. A stalled loop then jumps to the
            # minute that is current when this process runs again.
            now = datetime.now(timezone.utc)
            for event in self.step(now):
                for handler in self._handlers:
                    result = handler(event.tick, event.candle, event.closed)
                    if asyncio.iscoroutine(result):
                        await result
            await asyncio.sleep(delay)


def default_runtime() -> MarketRuntime:
    _ = ASSET_CONFIGS
    return MarketRuntime()
