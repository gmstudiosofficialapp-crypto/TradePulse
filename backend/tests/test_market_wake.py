"""Idle market runtime must wake on the first HTTP/WS client."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from fastapi.testclient import TestClient

from app.core.runtime import get_runtime
from app.main import create_app
from market_engine.config.assets import ASSET_CONFIGS
from market_engine.config.settings import EngineSettings
from market_engine.models.tick import Tick
from market_engine.services.market_runtime import MarketRuntime

ASSET = "BTC/USD-OTC"
AUTH_A = {"Authorization": "Bearer user-a|a@tradepulse.test"}
AUTH_B = {"Authorization": "Bearer user-b|b@tradepulse.test"}


def _runtime() -> MarketRuntime:
    runtime = MarketRuntime(
        settings=EngineSettings(history_size=4, warmup_ticks_per_minute=2),
        assets=[ASSET_CONFIGS[ASSET]],
    )
    runtime.warmup()
    return runtime


def _age_idle(runtime: MarketRuntime, hours: int = 2) -> datetime:
    past = datetime.now(timezone.utc) - timedelta(hours=hours)
    runtime.running = False
    runtime._task = None
    runtime._last_step_at = past
    for symbol, tick in list(runtime.quotes.items()):
        runtime.quotes[symbol] = Tick(asset=tick.asset, timestamp=past, price=tick.price)
    for candle in runtime.open_candles.values():
        candle.open_time = past.replace(second=0, microsecond=0)
        candle.close_time = past
    return past


def test_http_and_ws_wake_stale_runtime_without_new_engine() -> None:
    runtime = _runtime()
    stale_at = _age_idle(runtime)
    assert runtime.loop_alive() is False
    assert runtime.is_stale() is True

    application = create_app(runtime=runtime, auto_start=False)
    with TestClient(application) as client:
        assert get_runtime() is runtime
        assert runtime.loop_alive() is False

        status = client.get("/api/market/status").json()
        assert status["state"] == "LIVE_SIMULATION"
        assert get_runtime() is runtime
        assert runtime.loop_alive() is True

        quotes = client.get("/api/market/quotes").json()
        assert quotes["state"] == "LIVE_SIMULATION"
        btc = next(item for item in quotes["quotes"] if item["asset"] == ASSET)
        fresh = datetime.fromisoformat(btc["timestamp"])
        if fresh.tzinfo is None:
            fresh = fresh.replace(tzinfo=timezone.utc)
        assert fresh > stale_at
        assert (datetime.now(timezone.utc) - fresh).total_seconds() < 5

        candles = client.get("/api/market/candles", params={"asset": ASSET, "limit": 20}).json()
        live = candles["candles"][-1]
        live_open = datetime.fromisoformat(live["open_time"])
        if live_open.tzinfo is None:
            live_open = live_open.replace(tzinfo=timezone.utc)
        now_floor = datetime.now(timezone.utc).replace(second=0, microsecond=0)
        assert live_open == now_floor
        assert live["closed"] is False

        with client.websocket_connect("/ws/market") as ws:
            hello = ws.receive_json()
            assert hello["type"] == "status"
            assert hello["state"] == "LIVE_SIMULATION"
            ws.send_json({"type": "subscribe", "asset": ASSET})
            assert ws.receive_json()["type"] == "subscribed"
            quote = ws.receive_json()
            assert quote["type"] == "quote"
            first_price = quote["data"]["price"]
            live_msg = None
            for _ in range(20):
                msg = ws.receive_json()
                if msg.get("type") in {"market_tick", "tick", "candle_update"}:
                    live_msg = msg
                    break
            assert live_msg is not None
            if live_msg["type"] == "candle_update":
                assert live_msg["candle"]["asset"] == ASSET
            else:
                assert live_msg["data"]["asset"] == ASSET
            assert first_price > 0

        again = client.get("/api/market/status").json()
        assert again["state"] == "LIVE_SIMULATION"
        assert get_runtime() is runtime
        assert runtime.loop_alive() is True


def test_dead_loop_is_restarted_once() -> None:
    runtime = _runtime()
    application = create_app(runtime=runtime, auto_start=False)
    with TestClient(application) as client:
        class _DeadTask:
            def done(self) -> bool:
                return True

        runtime.running = True
        runtime._task = _DeadTask()  # type: ignore[assignment]
        status = client.get("/api/market/status").json()
        assert status["state"] == "LIVE_SIMULATION"
        first_task = runtime._task
        assert first_task is not None and not first_task.done()
        client.get("/api/market/quotes")
        assert runtime._task is first_task
        assert get_runtime() is runtime


def test_two_clients_share_woken_market_and_keep_trades_isolated() -> None:
    runtime = _runtime()
    _age_idle(runtime, hours=2)
    application = create_app(runtime=runtime, auto_start=False)
    with TestClient(application) as client:
        with client.websocket_connect("/ws/market") as ws_a, client.websocket_connect(
            "/ws/market"
        ) as ws_b:
            hello_a = ws_a.receive_json()
            hello_b = ws_b.receive_json()
            assert hello_a["state"] == hello_b["state"] == "LIVE_SIMULATION"
            ws_a.send_json({"type": "subscribe", "asset": ASSET})
            ws_b.send_json({"type": "subscribe", "asset": ASSET})
            assert ws_a.receive_json()["type"] == "subscribed"
            assert ws_b.receive_json()["type"] == "subscribed"
            quote_a = ws_a.receive_json()
            quote_b = ws_b.receive_json()
            assert quote_a["data"]["price"] == quote_b["data"]["price"]
            assert quote_a["data"]["timestamp"] == quote_b["data"]["timestamp"]

        quotes = client.get("/api/market/quotes").json()["quotes"]
        http_price = next(item for item in quotes if item["asset"] == ASSET)["price"]
        trade_a = client.post(
            "/api/demo/trades",
            headers=AUTH_A,
            json={"asset": ASSET, "direction": "BUY", "stake": 10, "expiry_seconds": 5},
        ).json()
        trade_b = client.post(
            "/api/demo/trades",
            headers=AUTH_B,
            json={"asset": ASSET, "direction": "SELL", "stake": 15, "expiry_seconds": 5},
        ).json()
        assert trade_a["user_id"] == "user-a"
        assert trade_b["user_id"] == "user-b"
        assert trade_a["entry_price"] == http_price or trade_a["entry_price"] > 0
        listed_a = client.get("/api/demo/trades", headers=AUTH_A).json()["trades"]
        listed_b = client.get("/api/demo/trades", headers=AUTH_B).json()["trades"]
        assert {item["trade_id"] for item in listed_a} == {trade_a["trade_id"]}
        assert {item["trade_id"] for item in listed_b} == {trade_b["trade_id"]}
        assert client.get("/api/demo/balance", headers=AUTH_A).json()["balance"] == 9990.0
        assert client.get("/api/demo/balance", headers=AUTH_B).json()["balance"] == 9985.0
        assert get_runtime() is runtime
