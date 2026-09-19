from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

from market_engine.models.candle import Candle
from signal_engine.config.settings import SignalSettings
from signal_engine.models.signal import Signal
from signal_engine.strategies.base import SignalStrategy
from signal_engine.strategies.momentum import MomentumStrategy


class SignalEngine:
    def __init__(
        self,
        settings: SignalSettings | None = None,
        strategy: SignalStrategy | None = None,
    ) -> None:
        self.settings = settings or SignalSettings()
        self.strategy = strategy or MomentumStrategy()
        self._signals: dict[str, Signal] = {}
        self._by_candle: set[tuple[str, datetime]] = set()

    def analyze_closed(
        self,
        asset: str,
        closed_candles: list[Candle],
        now: datetime | None = None,
    ) -> Signal:
        moment = now or datetime.now(timezone.utc)
        latest = closed_candles[-1] if closed_candles else None
        if latest is None or not latest.closed:
            return self._none(asset, moment, 0.0)
        key = (asset, latest.open_time)
        if key in self._by_candle:
            existing = next(
                (
                    s
                    for s in self._signals.values()
                    if s.asset == asset and s.candle_open_time == latest.open_time
                ),
                None,
            )
            return existing or self._none(asset, moment, 0.0, latest)
        # Generation algorithm is unchanged: strategy.analyze on closed candles only.
        direction, confidence = self.strategy.analyze(closed_candles, self.settings)
        self._by_candle.add(key)
        if direction == "NO_SIGNAL":
            return self._none(asset, moment, confidence, latest)
        if len(self.active_for(asset)) >= self.settings.max_active_per_asset:
            return self._none(asset, moment, confidence, latest)
        signal = Signal(
            signal_id=str(uuid.uuid4()),
            asset=asset,
            direction=direction,
            generated_at=moment,
            entry_price=latest.close,
            expiry_time=moment + timedelta(seconds=self.settings.expiry_seconds),
            confidence=confidence,
            status="SIGNAL_CREATED",
            source=self.settings.version,
            expiry_seconds=self.settings.expiry_seconds,
            candle_open_time=latest.open_time,
        )
        signal.status = "ACTIVE"
        self._signals[signal.signal_id] = signal
        return signal

    def latest_for(self, asset: str) -> Signal | None:
        items = self.directional_for(asset)
        if not items:
            return None
        active = [item for item in items if item.result is None]
        pool = active or items
        return max(pool, key=lambda item: item.generated_at)

    def directional_for(self, asset: str) -> list[Signal]:
        return [
            signal
            for signal in self._signals.values()
            if signal.asset == asset and signal.direction in {"BUY", "SELL"}
        ]

    def active_for(self, asset: str) -> list[Signal]:
        return [signal for signal in self.directional_for(asset) if signal.result is None]

    def all_signals(self) -> list[Signal]:
        return list(self._signals.values())

    def settle(self, signal_id: str, expiry_price: float, now: datetime | None = None) -> Signal:
        signal = self._signals[signal_id]
        if signal.result is not None:
            return signal
        moment = now or datetime.now(timezone.utc)
        if signal.direction == "NO_SIGNAL":
            signal.status = "CLOSED"
            signal.result = "NO_SIGNAL"
            signal.expiry_price = expiry_price
            signal.close_price = expiry_price
            signal.closed_at = moment
            return signal
        if signal.direction == "BUY":
            result = (
                "WIN"
                if expiry_price > signal.entry_price
                else "LOSS"
                if expiry_price < signal.entry_price
                else "DRAW"
            )
        else:
            result = (
                "WIN"
                if expiry_price < signal.entry_price
                else "LOSS"
                if expiry_price > signal.entry_price
                else "DRAW"
            )
        signal.expiry_price = expiry_price
        signal.close_price = expiry_price
        signal.closed_at = moment
        signal.result = result
        signal.status = "CLOSED"
        return signal

    def _none(
        self,
        asset: str,
        moment: datetime,
        confidence: float,
        latest: Candle | None = None,
    ) -> Signal:
        return Signal(
            signal_id=str(uuid.uuid4()),
            asset=asset,
            direction="NO_SIGNAL",
            generated_at=moment,
            entry_price=latest.close if latest else 0.0,
            expiry_time=moment + timedelta(seconds=self.settings.expiry_seconds),
            confidence=confidence,
            status="EXPIRED",
            source=self.settings.version,
            candle_open_time=latest.open_time if latest else None,
            result="NO_SIGNAL",
        )
