from __future__ import annotations

import json

from fastapi import APIRouter, HTTPException, WebSocket, WebSocketDisconnect

from app.core.firebase_admin_app import FirebaseAdminConfigError
from app.core.firebase_auth import verify_id_token
from app.core.market_hub import MarketHub, PrivateReferenceHub
from app.core.runtime import ensure_market_runtime, get_coordinator, get_runtime
from market_engine.config.assets import ASSET_CONFIGS

router = APIRouter()
hub = MarketHub()
private_hub = PrivateReferenceHub()


async def _on_phase3_event(payload: dict) -> None:
    if payload.get("type") == "ground_truth":
        await private_hub.broadcast(payload)
        return
    await hub.broadcast_event(payload)


def attach_hub() -> MarketHub:
    runtime = get_runtime()
    runtime.add_handler(hub.broadcast_tick)
    coordinator = get_coordinator()
    coordinator.add_event_handler(_on_phase3_event)
    coordinator.enable_live()
    runtime.add_handler(coordinator.on_market)
    from app.api.signal import attach_signal_feed

    attach_signal_feed()
    return hub


@router.websocket("/ws/market")
async def market_socket(websocket: WebSocket) -> None:
    runtime = await ensure_market_runtime()
    await websocket.accept()
    hub.connect(websocket)
    await hub.send(
        websocket,
        {
            "type": "status",
            "state": "LIVE_SIMULATION" if runtime.loop_alive() else "MARKET_OFFLINE",
            "simulated": True,
            "message": "Simulated OTC market. Not live-money trading.",
        },
    )
    try:
        while True:
            raw = await websocket.receive_text()
            try:
                message = json.loads(raw)
            except json.JSONDecodeError:
                await hub.send(websocket, {"type": "error", "message": "Invalid JSON"})
                continue
            if not isinstance(message, dict):
                await hub.send(websocket, {"type": "error", "message": "Invalid message"})
                continue
            kind = message.get("type")
            asset = message.get("asset")
            if kind == "ping":
                await hub.send(websocket, {"type": "pong"})
                continue
            if kind == "identify":
                token = str(
                    message.get("token") or message.get("access_token") or ""
                ).strip()
                if not token:
                    await hub.send(
                        websocket,
                        {"type": "error", "message": "Authorization token required"},
                    )
                    continue
                try:
                    user = verify_id_token(token)
                except FirebaseAdminConfigError as exc:
                    await hub.send(websocket, {"type": "error", "message": str(exc)})
                    continue
                except HTTPException as exc:
                    await hub.send(
                        websocket,
                        {"type": "error", "message": str(exc.detail)},
                    )
                    continue
                hub.identify(websocket, user.uid)
                await hub.send(websocket, {"type": "identified", "user_id": user.uid})
                continue
            if kind == "subscribe":
                if asset not in ASSET_CONFIGS:
                    await hub.send(websocket, {"type": "error", "message": "Unknown OTC asset"})
                    continue
                runtime = await ensure_market_runtime()
                hub.subscribe(websocket, asset)
                await hub.send(websocket, {"type": "subscribed", "asset": asset})
                quote = runtime.snapshot_quote(asset)
                if quote is not None:
                    await hub.send(websocket, {"type": "quote", "asset": asset, "data": quote})
                continue
            if kind == "unsubscribe":
                if isinstance(asset, str):
                    hub.unsubscribe(websocket, asset)
                    await hub.send(websocket, {"type": "unsubscribed", "asset": asset})
                continue
            await hub.send(websocket, {"type": "error", "message": "Unsupported message type"})
    except WebSocketDisconnect:
        hub.disconnect(websocket)
    except Exception:
        hub.disconnect(websocket)


@router.websocket("/ws/private-reference")
async def private_reference_socket(websocket: WebSocket) -> None:
    runtime = get_runtime()
    await websocket.accept()
    private_hub.connect(websocket)
    await private_hub.send(
        websocket,
        {
            "type": "status",
            "label": "PRIVATE TEST / GROUND TRUTH",
            "not_a_prediction": True,
            "simulated": True,
            "message": "Isolated reference channel. Not a user-facing prediction feed.",
        },
    )
    try:
        while True:
            raw = await websocket.receive_text()
            try:
                message = json.loads(raw)
            except json.JSONDecodeError:
                await private_hub.send(websocket, {"type": "error", "message": "Invalid JSON"})
                continue
            kind = message.get("type") if isinstance(message, dict) else None
            if kind == "ping":
                await private_hub.send(websocket, {"type": "pong"})
                continue
            if kind == "subscribe":
                asset = message.get("asset")
                stream = runtime.streams.get(asset)
                if stream is None:
                    await private_hub.send(websocket, {"type": "error", "message": "Unknown OTC asset"})
                    continue
                truth = get_coordinator().latest_truth.get(asset)
                if truth is None:
                    from app.services.ground_truth import peek_reference_direction

                    truth = peek_reference_direction(stream)
                await private_hub.send(
                    websocket,
                    {"type": "ground_truth", **truth},
                )
                continue
            await private_hub.send(websocket, {"type": "error", "message": "Unsupported message type"})
    except WebSocketDisconnect:
        private_hub.disconnect(websocket)
    except Exception:
        private_hub.disconnect(websocket)
