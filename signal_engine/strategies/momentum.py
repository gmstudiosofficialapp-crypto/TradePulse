from __future__ import annotations

from market_engine.models.candle import Candle
from signal_engine.config.settings import SignalSettings
from signal_engine.models.signal import Direction


class MomentumStrategy:
    def analyze(
        self,
        candles: list[Candle],
        settings: SignalSettings,
    ) -> tuple[Direction, float]:
        closed = [c for c in candles if c.closed]
        if len(closed) < 8:
            return "NO_SIGNAL", 0.0
        window = closed[-8:]
        last = window[-1]
        rng = last.high - last.low
        if rng <= 0:
            return "NO_SIGNAL", 0.0
        body = abs(last.close - last.open) / rng
        if body < settings.min_body_ratio:
            return "NO_SIGNAL", 0.2
        closes = [c.close for c in window]
        sma_fast = sum(closes[-3:]) / 3
        sma_slow = sum(closes) / len(closes)
        trend = (sma_fast - sma_slow) / sma_slow if sma_slow else 0.0
        ups = sum(1 for c in window[-3:] if c.close > c.open)
        downs = sum(1 for c in window[-3:] if c.close < c.open)
        momentum = (closes[-1] - closes[-4]) / closes[-4] if closes[-4] else 0.0
        returns = [
            abs(window[i].close - window[i - 1].close) / window[i - 1].close
            for i in range(1, len(window))
            if window[i - 1].close
        ]
        chop = (sum(returns) / len(returns)) if returns else 0.0
        if chop > settings.choppiness_limit:
            return "NO_SIGNAL", 0.25
        bullish = last.close > last.open and trend > settings.min_trend and ups >= 2 and momentum > 0
        bearish = last.close < last.open and trend < -settings.min_trend and downs >= 2 and momentum < 0
        strength = min(1.0, body * 0.45 + min(abs(trend) * 80, 0.35) + min(abs(momentum) * 40, 0.25))
        if bullish and strength >= settings.min_confidence:
            return "BUY", strength
        if bearish and strength >= settings.min_confidence:
            return "SELL", strength
        return "NO_SIGNAL", strength

    def generateSignal(
        self,
        candles: list[Candle],
        settings: SignalSettings,
    ) -> tuple[Direction, float]:
        return self.analyze(candles, settings)
