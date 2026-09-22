from __future__ import annotations

import json
from typing import Any

from fastapi import WebSocket

from app.services.signal_contract import build_signal_payload
from market_engine.models.candle import Candle
from market_engine.models.tick import Tick
from market_engine.services.btc_future_book import BTC_SYMBOL
from market_engine.services.market_runtime import MarketRuntime


class SignalFutureHub:
    def __init__(self) -> None:
        self._clients: set[WebSocket] = set()
        self._sequence = 0
        self._last_live_open: str | None = None
        self._last_closed: Candle | None = None

    def connect(self, websocket: WebSocket) -> None:
        self._clients.add(websocket)

    def disconnect(self, websocket: WebSocket) -> None:
        self._clients.discard(websocket)

    def next_sequence(self) -> int:
        self._sequence += 1
        return self._sequence

    def envelope(self, runtime: MarketRuntime, message_type: str, closed: Candle | None = None) -> dict | None:
        raw = runtime.btc_future_snapshot()
        # Snapshots and live updates repeat the last closed candle so a missed
        # roll can still be matched. The candle is the one the book just closed.
        remembered = closed if closed is not None else self._last_closed
        closed_payload = None
        if remembered is not None:
            closed_payload = {
                "asset": remembered.asset,
                "candle_start_time": remembered.open_time.isoformat(),
                "candle_end_time": remembered.close_time.isoformat(),
                "open": remembered.open,
                "high": remembered.high,
                "low": remembered.low,
                "close": remembered.close,
                "direction": "UP"
                if remembered.close > remembered.open
                else "DOWN"
                if remembered.close < remembered.open
                else "FLAT",
                "volume": remembered.volume,
                "closed": True,
            }
        return build_signal_payload(
            raw,
            message_type=message_type,
            sequence=self.next_sequence(),
            closed=closed_payload,
        )

    async def send(self, websocket: WebSocket, payload: dict[str, Any]) -> None:
        await websocket.send_text(json.dumps(payload))

    async def broadcast(self, payload: dict[str, Any]) -> None:
        message = json.dumps(payload)
        stale: list[WebSocket] = []
        for websocket in list(self._clients):
            try:
                await websocket.send_text(message)
            except Exception:
                stale.append(websocket)
        for websocket in stale:
            self.disconnect(websocket)

    async def on_market(self, tick: Tick, _candle, closed: Candle | None) -> None:
        if tick.asset != BTC_SYMBOL:
            return
        from app.core.runtime import get_runtime

        runtime = get_runtime()
        live = runtime.btc_future_snapshot().get("live") or {}
        live_open = live.get("candle_start_time")
        if closed is not None and live_open != self._last_live_open:
            self._last_live_open = live_open
            self._last_closed = closed
            payload = self.envelope(runtime, "roll", closed)
            if payload is not None:
                await self.broadcast(payload)
            return
        if self._last_live_open is None:
            self._last_live_open = live_open
        payload = self.envelope(runtime, "live_update")
        if payload is not None:
            await self.broadcast(payload)


signal_hub = SignalFutureHub()
