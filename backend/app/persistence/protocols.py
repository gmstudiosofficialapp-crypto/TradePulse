from __future__ import annotations

from typing import Protocol

from market_engine.models.candle import Candle


class TradeRecord(Protocol):
    trade_id: str


class DemoAccountStore(Protocol):
    def get_balance(self, user_id: str) -> float: ...

    def set_balance(self, user_id: str, amount: float) -> None: ...


class TradeStore(Protocol):
    def save(self, trade: dict) -> None: ...

    def get(self, trade_id: str) -> dict | None: ...

    def list_for_user(self, user_id: str) -> list[dict]: ...

    def all_open(self) -> list[dict]: ...


class SignalStore(Protocol):
    def save(self, payload: dict) -> None: ...

    def list_for_asset(self, asset: str) -> list[dict]: ...


class CandlePersistence(Protocol):
    def history(self, asset: str, limit: int | None = None) -> list[Candle]: ...
