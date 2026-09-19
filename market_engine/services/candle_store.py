from __future__ import annotations

from collections import deque
from typing import Protocol

from market_engine.models.candle import Candle


class CandleStore(Protocol):
    def append(self, candle: Candle) -> None: ...

    def history(self, asset: str, limit: int | None = None) -> list[Candle]: ...

    def replace(self, asset: str, candles: list[Candle]) -> None: ...

    def size(self, asset: str) -> int: ...


class MemoryCandleStore:
    """In-memory rolling buffer. PostgreSQL can replace this later."""

    def __init__(self, maxlen: int = 500) -> None:
        self.maxlen = maxlen
        self._data: dict[str, deque[Candle]] = {}

    def append(self, candle: Candle) -> None:
        bucket = self._data.setdefault(candle.asset, deque(maxlen=self.maxlen))
        bucket.append(candle)

    def history(self, asset: str, limit: int | None = None) -> list[Candle]:
        bucket = list(self._data.get(asset, ()))
        if limit is None:
            return bucket
        return bucket[-limit:]

    def replace(self, asset: str, candles: list[Candle]) -> None:
        self._data[asset] = deque(candles[-self.maxlen :], maxlen=self.maxlen)

    def size(self, asset: str) -> int:
        return len(self._data.get(asset, ()))
