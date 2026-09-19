from __future__ import annotations

from typing import Protocol

from market_engine.models.candle import Candle
from signal_engine.config.settings import SignalSettings
from signal_engine.models.signal import Direction


class SignalStrategy(Protocol):
    def analyze(
        self,
        candles: list[Candle],
        settings: SignalSettings,
    ) -> tuple[Direction, float]:
        """Return direction and confidence from CLOSED candles only."""
