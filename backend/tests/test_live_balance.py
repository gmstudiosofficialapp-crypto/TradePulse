from fastapi.testclient import TestClient

from app.core.runtime import get_trading
from app.main import create_app
from app.persistence.memory import (
    MemoryAccountStore,
    MemoryLedger,
    MemoryTradeStore,
    MemoryTransactionStore,
)
from app.services.demo_trading import BOOK_DEMO, BOOK_LIVE, DemoTradingEngine
from market_engine.config.assets import ASSET_CONFIGS
from market_engine.config.settings import EngineSettings
from market_engine.services.market_runtime import MarketRuntime

ASSET = "BTC/USD-OTC"
AUTH_A = {"Authorization": "Bearer user-a|a@tradepulse.test"}
AUTH_B = {"Authorization": "Bearer user-b|b@tradepulse.test"}


def _client() -> TestClient:
    runtime = MarketRuntime(
        settings=EngineSettings(history_size=4, warmup_ticks_per_minute=2),
        assets=[ASSET_CONFIGS[ASSET]],
    )
    runtime.warmup()
    return TestClient(create_app(runtime=runtime, auto_start=False))


def test_live_balances_are_isolated_and_independent_of_demo() -> None:
    with _client() as client:
        engine = get_trading()
        engine.set_live_balance("user-a", 1000)
        engine.set_live_balance("user-b", 500)
        assert engine.balance("user-a") == 10000.0
        assert engine.balance("user-b") == 10000.0

        trade_a = client.post(
            "/api/demo/trades",
            headers=AUTH_A,
            json={"asset": ASSET, "direction": "BUY", "stake": 100, "live": True},
        )
        assert trade_a.status_code == 200
        assert trade_a.json()["account_type"] == BOOK_LIVE
        assert trade_a.json()["user_id"] == "user-a"

        trade_b = client.post(
            "/api/demo/trades",
            headers=AUTH_B,
            json={"asset": ASSET, "direction": "SELL", "stake": 50, "live": True},
        )
        assert trade_b.status_code == 200
        assert trade_b.json()["user_id"] == "user-b"

        assert client.get("/api/live/balance", headers=AUTH_A).json()["balance"] == 900.0
        assert client.get("/api/live/balance", headers=AUTH_B).json()["balance"] == 450.0
        assert client.get("/api/demo/balance", headers=AUTH_A).json()["balance"] == 10000.0
        assert client.get("/api/demo/balance", headers=AUTH_B).json()["balance"] == 10000.0

        listed_a = client.get("/api/live/trades", headers=AUTH_A).json()["trades"]
        listed_b = client.get("/api/live/trades", headers=AUTH_B).json()["trades"]
        assert {item["trade_id"] for item in listed_a} == {trade_a.json()["trade_id"]}
        assert {item["trade_id"] for item in listed_b} == {trade_b.json()["trade_id"]}
        assert client.get("/api/demo/trades", headers=AUTH_A).json()["trades"] == []
        assert client.get("/api/live/balance", headers=AUTH_B).json()["user_id"] == "user-b"


def test_live_balance_persists_across_engine_restart() -> None:
    accounts = MemoryAccountStore(10000)
    trades = MemoryTradeStore()
    txns = MemoryTransactionStore()
    first = DemoTradingEngine(
        accounts=accounts,
        trades=trades,
        transactions=txns,
        ledger=MemoryLedger(accounts, trades, txns),
    )
    first.set_live_balance("alice", 1000)
    first.open_trade("alice", ASSET, "BUY", 100, 100, live=True)
    assert first.live_balance("alice") == 900.0
    assert first.balance("alice") == 10000.0

    restarted = DemoTradingEngine(
        accounts=accounts,
        trades=trades,
        transactions=txns,
        ledger=MemoryLedger(accounts, trades, txns),
    )
    assert restarted.live_balance("alice") == 900.0
    assert restarted.balance("alice") == 10000.0
    assert restarted.listed_trades("alice", BOOK_LIVE)[0]["stake"] == 100
    assert restarted.listed_trades("alice", BOOK_DEMO) == []


def test_live_settlement_does_not_touch_demo_or_other_users() -> None:
    engine = DemoTradingEngine()
    engine.set_live_balance("user-a", 1000)
    engine.set_live_balance("user-b", 500)
    live = engine.open_trade("user-a", ASSET, "BUY", 100, 100, live=True)
    demo = engine.open_trade("user-a", ASSET, "BUY", 10, 100, live=False)
    other = engine.open_trade("user-b", ASSET, "SELL", 50, 100, live=True)
    engine.settle(live["trade_id"], 110)
    engine.settle(other["trade_id"], 110)
    assert engine.live_balance("user-a") == 1092.0
    assert engine.live_balance("user-b") == 450.0
    assert engine.balance("user-a") == 9990.0
    assert engine.statistics("user-a", BOOK_LIVE)["wins"] == 1
    assert engine.statistics("user-a", BOOK_DEMO)["total_trades"] == 0
    engine.settle(demo["trade_id"], 90)
    assert engine.balance("user-a") == 9990.0
    assert engine.statistics("user-a", BOOK_DEMO)["losses"] == 1
    assert engine.live_balance("user-a") == 1092.0
