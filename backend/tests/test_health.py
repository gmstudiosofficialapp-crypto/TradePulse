import json

from fastapi.testclient import TestClient

from app.main import app, create_app
from market_engine.config.assets import ASSET_CONFIGS
from market_engine.config.settings import EngineSettings
from market_engine.services.market_runtime import MarketRuntime


def test_health() -> None:
    with TestClient(app) as client:
        response = client.get("/health")
        assert response.status_code == 200
        payload = response.json()
        assert payload["status"] == "ok"
        assert payload["service"] == "tradepulse-backend"


def test_quotes_and_candles() -> None:
    with TestClient(app) as client:
        status = client.get("/api/market/status").json()
        assert status["simulated"] is True
        assert status["state"] in {"LIVE_SIMULATION", "MARKET_OFFLINE"}
        quotes = client.get("/api/market/quotes").json()
        assert len(quotes["quotes"]) == 20
        btc = next(item for item in quotes["quotes"] if item["asset"] == "BTC/USD-OTC")
        assert btc["price"] > 0
        candles = client.get(
            "/api/market/candles",
            params={"asset": "BTC/USD-OTC", "limit": 20},
        ).json()
        assert candles["timeframe"] == "1m"
        assert len(candles["candles"]) >= 1


def test_websocket_subscribe_and_invalid_message() -> None:
    runtime = MarketRuntime(
        settings=EngineSettings(history_size=4, warmup_ticks_per_minute=2),
        assets=[ASSET_CONFIGS["BTC/USD-OTC"]],
    )
    runtime.warmup()
    test_app = create_app(runtime=runtime, auto_start=False)
    with TestClient(test_app) as client:
        with client.websocket_connect("/ws/market") as socket:
            hello = socket.receive_json()
            assert hello["type"] == "status"
            socket.send_text("not-json")
            error = socket.receive_json()
            assert error["type"] == "error"
            socket.send_json({"type": "subscribe", "asset": "NOPE"})
            unknown = socket.receive_json()
            assert unknown["type"] == "error"
            socket.send_json({"type": "subscribe", "asset": "BTC/USD-OTC"})
            subscribed = socket.receive_json()
            assert subscribed["type"] == "subscribed"
            quote = socket.receive_json()
            assert quote["type"] == "quote"
            socket.send_json({"type": "unsubscribe", "asset": "BTC/USD-OTC"})
            gone = socket.receive_json()
            assert gone["type"] == "unsubscribed"
            socket.send_json({"type": "ping"})
            pong = socket.receive_json()
            assert pong["type"] == "pong"


def test_websocket_disconnect() -> None:
    with TestClient(app) as client:
        with client.websocket_connect("/ws/market") as socket:
            socket.receive_json()
        with client.websocket_connect("/ws/market") as socket:
            payload = socket.receive_json()
            assert payload["type"] == "status"
