from concurrent.futures import ThreadPoolExecutor

from fastapi.testclient import TestClient

from app.core.runtime import get_trading
from app.main import create_app
from app.persistence.memory import MemoryAccountStore, SIGNUP_LIVE_BONUS
from app.services.demo_trading import BOOK_DEMO, BOOK_LIVE
from market_engine.config.assets import ASSET_CONFIGS
from market_engine.config.settings import EngineSettings
from market_engine.services.market_runtime import MarketRuntime

ASSET = "BTC/USD-OTC"
NEW = {"Authorization": "Bearer new-user|new@tradepulse.test"}
OLD = {"Authorization": "Bearer old-user|old@tradepulse.test"}


def _client() -> TestClient:
    runtime = MarketRuntime(
        settings=EngineSettings(history_size=4, warmup_ticks_per_minute=2),
        assets=[ASSET_CONFIGS[ASSET]],
    )
    runtime.warmup()
    return TestClient(create_app(runtime=runtime, auto_start=False))


def test_new_account_receives_signup_live_bonus() -> None:
    with _client() as client:
        created = client.post("/api/me", headers=NEW)
        assert created.status_code == 200
        body = created.json()
        assert body["balance"] == 10000.0
        assert body["live_balance"] == SIGNUP_LIVE_BONUS
        assert body["signup_bonus_granted"] is True
        assert body["signup_bonus_just_granted"] is True
        assert get_trading().balance("new-user") == 10000.0
        assert get_trading().live_balance("new-user") == 10.0


def test_existing_account_does_not_receive_bonus() -> None:
    with _client() as client:
        engine = get_trading()
        store: MemoryAccountStore = engine.accounts
        store._balances["old-user"] = 10000.0
        store._live_balances["old-user"] = 0.0
        store._users["old-user"] = {
            "uid": "old-user",
            "email": "old@tradepulse.test",
            "displayName": "Existing",
            "status": "active",
        }
        body = client.post("/api/me", headers=OLD).json()
        assert body["balance"] == 10000.0
        assert body["live_balance"] == 0.0
        assert body["signup_bonus_granted"] is False
        assert body["signup_bonus_just_granted"] is False
        assert engine.live_balance("old-user") == 0.0


def test_repeated_ensure_does_not_increase_live_balance() -> None:
    with _client() as client:
        first = client.post("/api/me", headers=NEW).json()
        assert first["live_balance"] == 10.0
        assert first["signup_bonus_just_granted"] is True
        second = client.post("/api/me", headers=NEW).json()
        third = client.get("/api/me", headers=NEW).json()
        assert second["live_balance"] == 10.0
        assert third["live_balance"] == 10.0
        assert second["signup_bonus_just_granted"] is False
        assert third["signup_bonus_just_granted"] is False
        assert second["signup_bonus_granted"] is True
        assert get_trading().live_balance("new-user") == 10.0


def test_concurrent_ensure_cannot_grant_bonus_twice() -> None:
    with _client() as client:
        def _call(_: int) -> dict:
            return client.post("/api/me", headers=NEW).json()

        with ThreadPoolExecutor(max_workers=8) as pool:
            rows = list(pool.map(_call, range(16)))
        granted = [row for row in rows if row.get("signup_bonus_just_granted")]
        assert len(granted) == 1
        assert all(row["live_balance"] == 10.0 for row in rows)
        assert get_trading().live_balance("new-user") == 10.0


def test_existing_live_and_demo_books_remain_intact() -> None:
    with _client() as client:
        engine = get_trading()
        engine.set_live_balance("old-user", 250)
        demo = client.post(
            "/api/demo/trades",
            headers=OLD,
            json={"asset": ASSET, "direction": "BUY", "stake": 100},
        )
        live = client.post(
            "/api/demo/trades",
            headers=OLD,
            json={"asset": ASSET, "direction": "SELL", "stake": 50, "live": True},
        )
        assert demo.status_code == 200
        assert live.status_code == 200
        assert demo.json()["account_type"] == BOOK_DEMO
        assert live.json()["account_type"] == BOOK_LIVE
        assert engine.balance("old-user") == 9900.0
        assert engine.live_balance("old-user") == 200.0
        me = client.get("/api/me", headers=OLD).json()
        assert me["signup_bonus_just_granted"] is False
        assert me["live_balance"] == 200.0
        assert me["balance"] == 9900.0
