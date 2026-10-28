from concurrent.futures import ThreadPoolExecutor

from fastapi.testclient import TestClient

from app.core.runtime import get_trading
from app.main import create_app
from app.persistence.memory import SIGNUP_LIVE_BONUS
from app.services.deposit import MSG_MAX, MSG_MIN, MSG_REASON_REQUIRED, STATUS_PENDING
from market_engine.config.assets import ASSET_CONFIGS
from market_engine.config.settings import EngineSettings
from market_engine.services.market_runtime import MarketRuntime

AUTH = {"Authorization": "Bearer deposit-user|deposit@tradepulse.test"}
OTHER = {"Authorization": "Bearer other-user|other@tradepulse.test"}
TXID = "abc123def456"


def _client() -> TestClient:
    runtime = MarketRuntime(
        settings=EngineSettings(history_size=3, warmup_ticks_per_minute=2),
        assets=[ASSET_CONFIGS["BTC/USD-OTC"]],
    )
    runtime.warmup()
    return TestClient(create_app(runtime=runtime, auto_start=False))


def _admin(client: TestClient) -> dict[str, str]:
    login = client.post(
        "/api/admin/login",
        json={"username": "test-admin", "password": "test-admin-pass"},
    )
    assert login.status_code == 200
    return {"Authorization": f"Bearer {login.json()['token']}"}


def _create(client: TestClient, amount: float, method: str = "btc", txid: str = TXID) -> dict:
    return client.post(
        "/api/live/deposits",
        headers=AUTH,
        json={"amount": amount, "method": method, "txid": txid, "user_id": "attacker"},
    )


def test_limits_do_not_create_records_or_credit() -> None:
    with _client() as client:
        engine = get_trading()
        engine.set_live_balance("deposit-user", 25)
        low = _create(client, 49.99)
        high = _create(client, 10000.01)
        assert low.status_code == 400
        assert high.status_code == 400
        assert low.json()["detail"] == MSG_MIN
        assert high.json()["detail"] == MSG_MAX
        assert engine.live_balance("deposit-user") == 25
        assert engine.deposits.list_for_user("deposit-user") == []


def test_bounds_are_accepted_without_crediting() -> None:
    with _client() as client:
        engine = get_trading()
        minimum = _create(client, 50, "usdt_trc20", "trx123456")
        maximum = _create(client, 10000, "eth_erc20", "0xabcDEF123456")
        assert minimum.status_code == 200
        assert maximum.status_code == 200
        assert minimum.json()["balance_credited"] is False
        assert minimum.json()["request"]["status"] == STATUS_PENDING
        assert minimum.json()["request"]["payment_method"] == "usdt_trc20"
        assert "user_id" not in minimum.json()["request"]
        assert engine.live_balance("deposit-user") == SIGNUP_LIVE_BONUS
        assert len(engine.deposits.list_for_user("deposit-user")) == 2


def test_approve_credits_once_and_reject_does_not() -> None:
    with _client() as client:
        engine = get_trading()
        created = _create(client, 250, "btc", "btcTXID12345")
        request_id = created.json()["request"]["request_id"]
        assert engine.live_balance("deposit-user") == SIGNUP_LIVE_BONUS
        admin = _admin(client)
        denied = client.post(f"/api/live/deposits/{request_id}/approve", headers=AUTH)
        assert denied.status_code in (401, 404, 405)
        first = client.post(f"/api/admin/deposits/{request_id}/approve", headers=admin)
        second = client.post(f"/api/admin/deposits/{request_id}/approve", headers=admin)
        assert first.status_code == 200
        assert second.status_code == 200
        assert first.json()["request"]["credited"] is True
        assert engine.live_balance("deposit-user") == SIGNUP_LIVE_BONUS + 250
        assert second.json()["live_balance"] == SIGNUP_LIVE_BONUS + 250

        rejected = _create(client, 100, "eth", "ethTX123456")
        reject_id = rejected.json()["request"]["request_id"]
        missing = client.post(
            f"/api/admin/deposits/{reject_id}/reject",
            headers=admin,
            json={},
        )
        assert missing.status_code == 400
        assert missing.json()["detail"] == MSG_REASON_REQUIRED
        done = client.post(
            f"/api/admin/deposits/{reject_id}/reject",
            headers=admin,
            json={"reason": "TXID could not be matched."},
        )
        assert done.status_code == 200
        assert done.json()["request"]["status"] == "Rejected"
        assert engine.live_balance("deposit-user") == SIGNUP_LIVE_BONUS + 250
        own = client.get("/api/live/deposits", headers=AUTH).json()["deposits"]
        assert {row["request_id"] for row in own} == {request_id, reject_id}
        other = client.get(f"/api/live/deposits/{request_id}", headers=OTHER)
        assert other.status_code == 404


def test_concurrent_approve_credits_once() -> None:
    with _client() as client:
        engine = get_trading()
        request_id = _create(client, 1000).json()["request"]["request_id"]
        admin = _admin(client)

        def _approve(_: int) -> int:
            return client.post(
                f"/api/admin/deposits/{request_id}/approve",
                headers=admin,
            ).status_code

        with ThreadPoolExecutor(max_workers=8) as pool:
            codes = list(pool.map(_approve, range(12)))
        assert set(codes) == {200}
        assert engine.live_balance("deposit-user") == SIGNUP_LIVE_BONUS + 1000
        assert engine.balance("deposit-user") == 10000
