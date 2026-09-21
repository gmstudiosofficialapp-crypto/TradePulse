from __future__ import annotations

import json

from fastapi import APIRouter, HTTPException, WebSocket, WebSocketDisconnect

from app.core.firebase_admin_app import FirebaseAdminConfigError
from app.core.firebase_auth import SignalFeedUser, verify_signal_feed_token
from app.core.runtime import get_runtime
from app.core.signal_hub import signal_hub
from market_engine.services.btc_future_book import BTC_SYMBOL

router = APIRouter()


def attach_signal_feed() -> None:
    runtime = get_runtime()
    runtime.add_handler(signal_hub.on_market)


@router.get("/api/signal/btc-future-book")
def signal_btc_future_book(user: SignalFeedUser) -> dict:
    _ = user
    payload = signal_hub.envelope(get_runtime(), "snapshot")
    if payload is None:
        raise HTTPException(status_code=503, detail="BTC future book is not ready")
    return payload


def _token_from_websocket(websocket: WebSocket, message: dict | None = None) -> str:
    header = websocket.headers.get("authorization") or ""
    if header.lower().startswith("bearer "):
        return header[7:].strip()
    query = websocket.query_params.get("access_token") or ""
    if query.strip():
        return query.strip()
    if message and message.get("type") == "auth":
        return str(message.get("token") or "").strip()
    return ""


@router.websocket("/ws/signal-btc-future")
async def signal_btc_future_socket(websocket: WebSocket) -> None:
    await websocket.accept()
    authed = False
    try:
        header_token = _token_from_websocket(websocket)
        if header_token:
            verify_signal_feed_token(header_token)
            authed = True
            await signal_hub.send(websocket, {"type": "authenticated", "asset": BTC_SYMBOL})
        while True:
            raw = await websocket.receive_text()
            try:
                message = json.loads(raw)
            except json.JSONDecodeError:
                await signal_hub.send(websocket, {"type": "error", "message": "Invalid JSON"})
                continue
            if not isinstance(message, dict):
                await signal_hub.send(websocket, {"type": "error", "message": "Invalid message"})
                continue
            kind = message.get("type")
            if not authed:
                if kind != "auth":
                    await websocket.close(code=4401)
                    return
                try:
                    verify_signal_feed_token(_token_from_websocket(websocket, message))
                except FirebaseAdminConfigError:
                    await websocket.close(code=1013)
                    return
                except Exception:
                    await websocket.close(code=4401)
                    return
                authed = True
                await signal_hub.send(websocket, {"type": "authenticated", "asset": BTC_SYMBOL})
                continue
            if kind == "ping":
                await signal_hub.send(websocket, {"type": "pong"})
                continue
            if kind == "subscribe":
                signal_hub.connect(websocket)
                payload = signal_hub.envelope(get_runtime(), "snapshot")
                if payload is None:
                    await signal_hub.send(
                        websocket, {"type": "error", "message": "BTC future book is not ready"}
                    )
                    continue
                await signal_hub.send(websocket, payload)
                continue
            if kind == "unsubscribe":
                signal_hub.disconnect(websocket)
                await signal_hub.send(websocket, {"type": "unsubscribed", "asset": BTC_SYMBOL})
                continue
            await signal_hub.send(websocket, {"type": "error", "message": "Unsupported message type"})
    except WebSocketDisconnect:
        signal_hub.disconnect(websocket)
    except Exception:
        signal_hub.disconnect(websocket)
        try:
            await websocket.close()
        except Exception:
            pass
