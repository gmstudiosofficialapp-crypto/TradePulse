from fastapi.testclient import TestClient

from app.core.safety import LIVE_TRADING_ENABLED
from app.main import create_app
from app.services.ground_truth import peek_reference_direction
from market_engine.config.assets import ASSET_CONFIGS
from market_engine.config.settings import EngineSettings
from market_engine.services.market_runtime import MarketRuntime
from signal_engine.services.engine import SignalEngine


def _app() -> tuple[TestClient, MarketRuntime]:
    runtime = MarketRuntime(
        settings=EngineSettings(history_size=12, warmup_ticks_per_minute=3),
        assets=[ASSET_CONFIGS["BTC/USD-OTC"], ASSET_CONFIGS["ETH/USD-OTC"]],
    )
    runtime.warmup()
    application = create_app(runtime=runtime, auto_start=False)
    return TestClient(application), runtime


def test_websocket_events_and_isolation() -> None:
    client, runtime = _app()
    with client:
        with client.websocket_connect("/ws/market") as public:
            hello = public.receive_json()
            assert hello["type"] == "status"
            public.send_json({"type": "subscribe", "asset": "BTC/USD-OTC"})
            assert public.receive_json()["type"] == "subscribed"
            quote = public.receive_json()
            assert quote["type"] == "quote"
            assert "reference_direction" not in quote
            assert "next_candle_result" not in str(quote)
        with client.websocket_connect("/ws/private-reference") as private:
            status = private.receive_json()
            assert status["label"] == "PRIVATE TEST / GROUND TRUTH"
            private.send_json({"type": "subscribe", "asset": "BTC/USD-OTC"})
            truth = private.receive_json()
            assert truth["type"] == "ground_truth"
            assert truth["not_a_prediction"] is True
            assert "reference_direction" in truth


def test_future_data_not_fed_to_signal_engine() -> None:
    runtime = MarketRuntime(
        settings=EngineSettings(history_size=12, warmup_ticks_per_minute=3),
        assets=[ASSET_CONFIGS["BTC/USD-OTC"]],
    )
    runtime.warmup()
    stream = runtime.streams["BTC/USD-OTC"]
    before = stream.ticks.price
    peek = peek_reference_direction(stream)
    after = stream.ticks.price
    assert before == after
    engine = SignalEngine()
    closed = [c for c in runtime.store.history("BTC/USD-OTC") if c.closed]
    signal = engine.analyze_closed("BTC/USD-OTC", closed)
    assert "reference" not in signal.to_dict()
    assert peek["not_a_prediction"] is True
    assert LIVE_TRADING_ENABLED is False


def test_demo_trade_api_uses_server_price() -> None:
    client, _runtime = _app()
    headers = {"Authorization": "Bearer trader|trader@example.com"}
    with client:
        opened = client.post(
            "/api/demo/trades",
            headers=headers,
            json={
                "asset": "BTC/USD-OTC",
                "direction": "BUY",
                "stake": 10,
                "entry_price": 1,
            },
        )
        assert opened.status_code == 200
        body = opened.json()
        assert body["entry_price"] != 1 or body["entry_price"] > 0
        live = client.post(
            "/api/demo/trades",
            headers=headers,
            json={
                "asset": "BTC/USD-OTC",
                "direction": "BUY",
                "stake": 10,
                "live": True,
            },
        )
        assert live.status_code == 400
        assert "live balance" in str(live.json()["detail"]).lower()
        private = client.get("/api/private/reference", params={"asset": "BTC/USD-OTC"})
        assert private.status_code == 200
        public_signal = client.get("/api/signals/latest", params={"asset": "BTC/USD-OTC"})
        assert "reference_direction" not in public_signal.json()
        futures = client.get("/api/private/btc-future-candles")
        assert futures.status_code == 200
        body = futures.json()
        assert body["asset"] == "BTC/USD-OTC"
        assert body["rolling"] is True
        assert body["future_count"] == 3
        assert len(body["futures"]) == 3
        public_quote = client.get("/api/market/quotes")
        text = str(public_quote.json())
        assert "precomputed" not in text
        assert "candle_start_time" not in text
