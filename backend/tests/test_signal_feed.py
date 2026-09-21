from datetime import datetime, timezone

from fastapi.testclient import TestClient

from app.core.signal_hub import signal_hub
from app.main import create_app
from market_engine.config.assets import ASSET_CONFIGS
from market_engine.config.settings import EngineSettings
from market_engine.services.btc_future_book import BTC_SYMBOL
from market_engine.services.market_runtime import MarketRuntime


def _app() -> tuple[TestClient, MarketRuntime]:
    runtime = MarketRuntime(
        settings=EngineSettings(history_size=2, warmup_ticks_per_minute=2),
        assets=[ASSET_CONFIGS[BTC_SYMBOL], ASSET_CONFIGS["ETH/USD-OTC"]],
    )
    runtime.warmup(datetime(2026, 9, 21, 16, 9, 20, tzinfo=timezone.utc))
    return TestClient(create_app(runtime=runtime, auto_start=False)), runtime


def _auth() -> dict[str, str]:
    return {"Authorization": "Bearer signal|signal@example.com"}


def test_signal_http_requires_auth_and_returns_snapshot() -> None:
    client, _runtime = _app()
    with client:
        denied = client.get("/api/signal/btc-future-book")
        assert denied.status_code == 401
        ok = client.get("/api/signal/btc-future-book", headers=_auth())
        assert ok.status_code == 200
        body = ok.json()
        assert body["schema_version"] == 1
        assert body["type"] == "snapshot"
        assert body["asset"] == BTC_SYMBOL
        assert body["future_count"] == 3
        assert len(body["futures"]) == 3
        assert body["live"]["role"] == "LIVE"
        assert body["futures"][0]["role"] == "FUTURE_1"
        assert body["futures"][2]["direction"] in {"UP", "DOWN", "FLAT"}


def test_public_surfaces_do_not_expose_future_book() -> None:
    client, _runtime = _app()
    with client:
        quotes = client.get("/api/market/quotes")
        text = str(quotes.json())
        assert "FUTURE_1" not in text
        assert "precomputed" not in text
        assert "schema_version" not in text
        with client.websocket_connect("/ws/market") as ws:
            hello = ws.receive_json()
            assert hello["type"] == "status"
            ws.send_json({"type": "subscribe", "asset": BTC_SYMBOL})
            assert ws.receive_json()["type"] == "subscribed"
            quote = ws.receive_json()
            assert quote["type"] == "quote"
            assert "futures" not in quote
            assert "FUTURE_1" not in str(quote)


def test_signal_ws_auth_snapshot_and_resync() -> None:
    client, runtime = _app()
    with client:
        with client.websocket_connect("/ws/signal-btc-future") as ws:
            ws.send_json({"type": "auth", "token": "signal|signal@example.com"})
            assert ws.receive_json()["type"] == "authenticated"
            ws.send_json({"type": "subscribe"})
            snap = ws.receive_json()
            assert snap["type"] == "snapshot"
            assert snap["future_count"] == 3
            first_future = snap["futures"][0]["id"]
            ws.send_json({"type": "ping"})
            assert ws.receive_json()["type"] == "pong"
        events = runtime.step(datetime(2026, 9, 21, 16, 10, tzinfo=timezone.utc))
        closed = next(
            (event.closed for event in events if event.tick.asset == BTC_SYMBOL and event.closed),
            None,
        )
        assert closed is not None
        rolled = signal_hub.envelope(runtime, "roll", closed)
        assert rolled is not None
        assert rolled["type"] == "roll"
        assert rolled["promoted_live_id"] == first_future
        assert rolled["live"]["id"] == first_future
        assert rolled["new_future_id"] == rolled["futures"][2]["id"]
        assert rolled["futures"][2]["candle_start_time"].startswith("2026-09-21T16:13:00")
        events = runtime.step(datetime(2026, 9, 21, 16, 11, tzinfo=timezone.utc))
        closed = next(
            (event.closed for event in events if event.tick.asset == BTC_SYMBOL and event.closed),
            None,
        )
        assert closed is not None
        second = signal_hub.envelope(runtime, "roll", closed)
        assert second["live"]["candle_start_time"].startswith("2026-09-21T16:11:00")
        assert second["futures"][2]["candle_start_time"].startswith("2026-09-21T16:14:00")
        http = client.get("/api/signal/btc-future-book", headers=_auth()).json()
        assert http["live"]["candle_start_time"].startswith("2026-09-21T16:11:00")
        with client.websocket_connect("/ws/signal-btc-future") as ws:
            ws.send_json({"type": "auth", "token": "invalid"})
        with client.websocket_connect("/ws/signal-btc-future") as ws:
            ws.send_json({"type": "auth", "token": "signal|signal@example.com"})
            assert ws.receive_json()["type"] == "authenticated"
            ws.send_json({"type": "subscribe"})
            resync = ws.receive_json()
            assert resync["type"] == "snapshot"
            assert resync["live"]["candle_start_time"].startswith("2026-09-21T16:11:00")
            assert len(resync["futures"]) == 3
