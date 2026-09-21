"""Live end-to-end TradePulse ↔ Signal App integration. No deploy, no signal logic."""

from __future__ import annotations

import os
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

os.environ.setdefault("TRADEPULSE_PERSISTENCE", "memory")
os.environ.setdefault("TRADEPULSE_HISTORY", "3")
os.environ.setdefault("TRADEPULSE_WARMUP_TICKS", "2")

ROOT = Path(__file__).resolve().parents[2]
SIGNAL_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "backend"))

from fastapi.testclient import TestClient

from app.core.firebase_auth import FirebaseUser, set_token_verifier
from app.core.runtime import get_runtime
from app.main import create_app
from app.services.signal_contract import build_signal_payload
from market_engine.config.assets import ASSET_CONFIGS
from market_engine.config.settings import EngineSettings
from market_engine.services.btc_future_book import BTC_SYMBOL
from market_engine.services.market_runtime import MarketRuntime

import importlib.util

_state_spec = importlib.util.spec_from_file_location(
    "signal_state", SIGNAL_ROOT / "app" / "state.py"
)
_state_mod = importlib.util.module_from_spec(_state_spec)
assert _state_spec.loader is not None
sys.modules["signal_state"] = _state_mod
_state_spec.loader.exec_module(_state_mod)
BtcFutureState = _state_mod.BtcFutureState


TOKEN = "e2e|e2e@tradepulse.test"
AUTH = {"Authorization": f"Bearer {TOKEN}"}
CANDLE_KEYS = (
    "id",
    "candle_start_time",
    "candle_end_time",
    "open",
    "high",
    "low",
    "close",
    "direction",
)


def _install_test_auth() -> None:
    def verify(token: str) -> FirebaseUser:
        if token.startswith("invalid") or token == "expired":
            from fastapi import HTTPException

            raise HTTPException(status_code=401, detail="Invalid or expired token")
        if "|" in token:
            uid, email = token.split("|", 1)
            return FirebaseUser(uid=uid, email=email, name="E2E")
        return FirebaseUser(uid=token, email=f"{token}@example.com", name="E2E")

    set_token_verifier(verify)


def _minute(ts: str) -> str:
    return datetime.fromisoformat(ts).astimezone(timezone.utc).strftime("%H:%M")


def _view(candle: dict) -> dict:
    return {key: candle[key] for key in CANDLE_KEYS}


def _book_view(runtime: MarketRuntime) -> dict:
    payload = build_signal_payload(
        runtime.btc_future_snapshot(),
        message_type="snapshot",
        sequence=0,
    )
    assert payload is not None
    return payload


def _compare(signal: dict, book: dict, label: str) -> None:
    assert signal["live"] is not None, f"{label}: missing live"
    assert len(signal["futures"]) == 3, f"{label}: need 3 futures"
    assert _view(signal["live"]) == _view(book["live"]), f"{label}: live mismatch"
    for index in range(3):
        assert _view(signal["futures"][index]) == _view(book["futures"][index]), (
            f"{label}: FUTURE_{index + 1} mismatch"
        )
    ids = [signal["live"]["id"], *(item["id"] for item in signal["futures"])]
    assert len(ids) == len(set(ids)), f"{label}: duplicate candle id {ids}"
    starts = [signal["live"]["candle_start_time"]] + [
        item["candle_start_time"] for item in signal["futures"]
    ]
    assert starts == sorted(starts), f"{label}: times not rolling forward {starts}"


def _wait_roll(client: TestClient, previous_live: str, timeout: float) -> dict:
    deadline = time.time() + timeout
    while time.time() < deadline:
        body = client.get("/api/signal/btc-future-book", headers=AUTH).json()
        if body["live"]["candle_start_time"] != previous_live:
            return body
        time.sleep(0.25)
    raise TimeoutError(f"no roll away from {previous_live} within {timeout}s")


def main() -> int:
    report = {
        "connected": False,
        "http_snapshot": False,
        "websocket": False,
        "live_next_display": False,
        "three_rolls": False,
        "ohlc_match": False,
        "reconnect": False,
        "stale_sequence": False,
        "public_clean": False,
        "cycles": [],
        "limitations": [],
    }
    _install_test_auth()
    runtime = MarketRuntime(
        settings=EngineSettings(history_size=3, warmup_ticks_per_minute=2),
        assets=[ASSET_CONFIGS[BTC_SYMBOL]],
    )
    application = create_app(runtime=runtime, auto_start=True)
    signal_app_ok = (SIGNAL_ROOT / "static" / "index.html").is_file()

    with TestClient(application) as client:
        health = client.get("/health")
        assert health.status_code == 200
        report["connected"] = True

        denied = client.get("/api/signal/btc-future-book")
        assert denied.status_code == 401

        snap = client.get("/api/signal/btc-future-book", headers=AUTH)
        assert snap.status_code == 200
        body = snap.json()
        assert body["type"] == "snapshot"
        assert body["future_count"] == 3
        book = _book_view(get_runtime())
        _compare(body, book, "initial")
        report["http_snapshot"] = True
        report["ohlc_match"] = True

        local = BtcFutureState()
        assert local.apply(body, allow_snapshot_reset=True)
        live_dt = datetime.fromisoformat(body["live"]["candle_start_time"])
        live_min = _minute(body["live"]["candle_start_time"])
        nxt = [_minute(item["candle_start_time"]) for item in body["futures"]]
        expected = [(live_dt + timedelta(minutes=offset)).strftime("%H:%M") for offset in (0, 1, 2, 3)]
        print(f"INITIAL LIVE={live_min} NEXT={nxt} seq={body['sequence']}")
        assert [live_min, *nxt] == expected
        report["live_next_display"] = True

        with client.websocket_connect("/ws/signal-btc-future") as ws:
            ws.send_json({"type": "auth", "token": TOKEN})
            assert ws.receive_json()["type"] == "authenticated"
            ws.send_json({"type": "subscribe"})
            ws_snap = ws.receive_json()
            assert ws_snap["type"] == "snapshot"
            local.apply(ws_snap, allow_snapshot_reset=True)
            report["websocket"] = True
            print(f"WS snapshot LIVE={_minute(ws_snap['live']['candle_start_time'])} seq={ws_snap['sequence']}")

            previous = body["live"]["candle_start_time"]
            for cycle in range(1, 4):
                rolled = _wait_roll(client, previous, timeout=90)
                book = _book_view(get_runtime())
                _compare(rolled, book, f"http-roll-{cycle}")
                local.apply({**rolled, "type": "snapshot"}, allow_snapshot_reset=True)
                starts = [_minute(rolled["live"]["candle_start_time"])] + [
                    _minute(item["candle_start_time"]) for item in rolled["futures"]
                ]
                print(f"ROLL {cycle} LIVE={starts[0]} NEXT={starts[1:]} seq={rolled['sequence']}")
                report["cycles"].append(starts)
                previous = rolled["live"]["candle_start_time"]
                # Drain any WS frames already queued (never block: TestClient receive has no timeout).
                try:
                    ws.send_json({"type": "ping"})
                    pong = ws.receive_json()
                    if pong.get("type") not in {"pong", "roll", "live_update", "snapshot"}:
                        report["limitations"].append(f"cycle {cycle}: unexpected WS after ping {pong.get('type')}")
                    elif pong.get("type") in {"roll", "live_update"}:
                        local.apply(pong)
                except Exception as exc:
                    report["limitations"].append(f"cycle {cycle}: WS ping {exc}")

            report["three_rolls"] = len(report["cycles"]) == 3

            stale = dict(rolled)
            stale["type"] = "live_update"
            stale["sequence"] = 1
            assert local.apply(stale) is False
            assert local.last_error == "stale_sequence"
            report["stale_sequence"] = True

        # Reconnect: HTTP snapshot then new WS subscribe
        local.mark_connected(False)
        resync = client.get("/api/signal/btc-future-book", headers=AUTH).json()
        assert local.apply(resync, allow_snapshot_reset=True)
        book = _book_view(get_runtime())
        _compare(resync, book, "reconnect-http")
        with client.websocket_connect("/ws/signal-btc-future") as ws:
            ws.send_json({"type": "auth", "token": TOKEN})
            assert ws.receive_json()["type"] == "authenticated"
            ws.send_json({"type": "subscribe"})
            again = ws.receive_json()
            assert again["type"] == "snapshot"
            assert local.apply(again, allow_snapshot_reset=True)
            assert again["live"]["id"] == resync["live"]["id"]
            ids = [again["live"]["id"], *(item["id"] for item in again["futures"])]
            assert len(ids) == 4
        report["reconnect"] = True

        quotes = client.get("/api/market/quotes").json()
        text = str(quotes)
        assert "FUTURE_1" not in text
        assert "schema_version" not in text
        assert "precomputed" not in text
        with client.websocket_connect("/ws/market") as pub:
            pub.receive_json()
            pub.send_json({"type": "subscribe", "asset": BTC_SYMBOL})
            pub.receive_json()
            quote = pub.receive_json()
            assert "FUTURE_1" not in str(quote)
            assert quote["type"] == "quote"
        report["public_clean"] = True

    if not signal_app_ok:
        report["limitations"].append("TradePulseSignal static UI missing")

    print("REPORT", report)
    failed = [
        name
        for name in (
            "connected",
            "http_snapshot",
            "websocket",
            "live_next_display",
            "three_rolls",
            "ohlc_match",
            "reconnect",
            "stale_sequence",
            "public_clean",
        )
        if not report[name]
    ]
    if failed:
        print("FAILED", failed)
        return 1
    print("LIVE_E2E_PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
