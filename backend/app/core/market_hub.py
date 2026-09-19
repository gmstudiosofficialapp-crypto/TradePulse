from __future__ import annotations

import json
from typing import Any

from fastapi import WebSocket

from market_engine.models.candle import Candle
from market_engine.models.tick import Tick


class MarketHub:
    def __init__(self) -> None:
        self._clients: dict[WebSocket, set[str]] = {}
        self._users: dict[WebSocket, str] = {}
        self._seen: dict[WebSocket, set[str]] = {}

    def connect(self, websocket: WebSocket) -> None:
        self._clients[websocket] = set()
        self._seen[websocket] = set()

    def disconnect(self, websocket: WebSocket) -> None:
        self._clients.pop(websocket, None)
        self._users.pop(websocket, None)
        self._seen.pop(websocket, None)

    def identify(self, websocket: WebSocket, user_id: str) -> None:
        self._users[websocket] = user_id

    def subscribe(self, websocket: WebSocket, asset: str) -> None:
        self._clients.setdefault(websocket, set()).add(asset)

    def unsubscribe(self, websocket: WebSocket, asset: str) -> None:
        if websocket in self._clients:
            self._clients[websocket].discard(asset)

    async def broadcast_tick(
        self,
        tick: Tick,
        candle: Candle,
        closed: Candle | None,
    ) -> None:
        tick_msg = {"type": "market_tick", "asset": tick.asset, "data": tick.to_dict()}
        legacy_tick = {"type": "tick", "asset": tick.asset, "data": tick.to_dict()}
        update_msg = {
            "type": "candle_update",
            "asset": tick.asset,
            "timeframe": "1m",
            "candle": candle.to_dict(),
        }
        close_msgs = []
        if closed is not None:
            payload = {
                "asset": closed.asset,
                "timeframe": "1m",
                "candle": closed.to_dict(),
            }
            close_msgs = [
                {"type": "candle_close", **payload},
                {"type": "candle_closed", **payload},
            ]
        stale: list[WebSocket] = []
        for websocket, assets in self._clients.items():
            if tick.asset not in assets:
                continue
            try:
                await websocket.send_text(json.dumps(tick_msg))
                await websocket.send_text(json.dumps(legacy_tick))
                await websocket.send_text(json.dumps(update_msg))
                for close_msg in close_msgs:
                    await websocket.send_text(json.dumps(close_msg))
            except Exception:
                stale.append(websocket)
        for websocket in stale:
            self.disconnect(websocket)

    async def broadcast_event(self, payload: dict[str, Any]) -> None:
        if "reference_direction" in payload or payload.get("type") == "ground_truth":
            return
        asset = payload.get("asset") or (payload.get("trade") or {}).get("asset")
        user_id = payload.get("user_id") or (payload.get("trade") or {}).get("user_id")
        stale: list[WebSocket] = []
        for websocket, assets in self._clients.items():
            if asset and assets and asset not in assets:
                if payload.get("type") not in {"balance_updated"}:
                    continue
            if payload.get("type") == "balance_updated":
                if self._users.get(websocket) not in {None, user_id}:
                    continue
            try:
                await websocket.send_text(json.dumps(payload))
            except Exception:
                stale.append(websocket)
        for websocket in stale:
            self.disconnect(websocket)

    async def send(self, websocket: WebSocket, payload: dict[str, Any]) -> None:
        await websocket.send_text(json.dumps(payload))


class PrivateReferenceHub:
    def __init__(self) -> None:
        self._clients: set[WebSocket] = set()

    def connect(self, websocket: WebSocket) -> None:
        self._clients.add(websocket)

    def disconnect(self, websocket: WebSocket) -> None:
        self._clients.discard(websocket)

    async def broadcast(self, payload: dict[str, Any]) -> None:
        stale: list[WebSocket] = []
        message = json.dumps(payload)
        for websocket in list(self._clients):
            try:
                await websocket.send_text(message)
            except Exception:
                stale.append(websocket)
        for websocket in stale:
            self.disconnect(websocket)

    async def send(self, websocket: WebSocket, payload: dict[str, Any]) -> None:
        await websocket.send_text(json.dumps(payload))
