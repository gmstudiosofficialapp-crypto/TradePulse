from concurrent.futures import ThreadPoolExecutor

from fastapi.testclient import TestClient

from app.core.runtime import get_trading
from app.main import create_app
from app.services.withdraw import (
    MSG_ADDRESS_REQUIRED,
    MSG_ALREADY_REJECTED,
    MSG_ALREADY_SUCCESSFUL,
    MSG_AMOUNT_REQUIRED,
    MSG_BKASH,
    MSG_BTC,
    MSG_ETH,
    MSG_INSUFFICIENT,
    MSG_MAX,
    MSG_METHOD,
    MSG_MIN,
    MSG_NAGAD,
    MSG_P2P_MAX,
    MSG_P2P_MIN,
    MSG_PENDING,
    MSG_REASON_REQUIRED,
    MSG_TRC20,
    STATUS_PENDING,
    STATUS_REJECTED,
    STATUS_SUCCESSFUL,
    SUBMITTED_MESSAGE,
    usd_to_bdt,
    validate_btc_address,
    validate_eth_address,
    validate_trc20_address,
)
from market_engine.config.assets import ASSET_CONFIGS
from market_engine.config.settings import EngineSettings
from market_engine.services.market_runtime import MarketRuntime

AUTH = {"Authorization": "Bearer withdraw-user|withdraw@tradepulse.test"}
OTHER = {"Authorization": "Bearer other-user|other@tradepulse.test"}
VALID_BTC = "1CUXN4MrQ9qyZBtqU6Pg4U7iZiy6Y3ztMt"
VALID_TRC20 = "THfnsscby3ZW3LPGbTyGLyLkFsFdRwV5Xq"
VALID_ETH = "0x27e711D1B6E4866EBf7904B3B631f6D05518E1B6"
VALID_BKASH = "01712345678"
VALID_NAGAD = "01812345678"


def _client() -> TestClient:
    runtime = MarketRuntime(
        settings=EngineSettings(history_size=4, warmup_ticks_per_minute=2),
        assets=[ASSET_CONFIGS["BTC/USD-OTC"]],
    )
    runtime.warmup()
    return TestClient(create_app(runtime=runtime, auto_start=False))


def _admin_headers(client: TestClient) -> dict[str, str]:
    login = client.post(
        "/api/admin/login",
        json={"username": "test-admin", "password": "test-admin-pass"},
    )
    assert login.status_code == 200
    return {"Authorization": f"Bearer {login.json()['token']}"}


def test_address_format_validation() -> None:
    assert validate_btc_address(VALID_BTC)
    assert validate_btc_address("3J98t1WpEZ73CNmYviecrnyiWrnqRhWNLy")
    assert validate_btc_address("bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4")
    assert not validate_btc_address("abc")
    assert not validate_btc_address("0x27e711D1B6E4866EBf7904B3B631f6D05518E1B6")
    assert validate_trc20_address(VALID_TRC20)
    assert not validate_trc20_address("Tshort")
    assert validate_eth_address(VALID_ETH)
    assert not validate_eth_address("0x12")
    assert usd_to_bdt(100) == 12400.0
    assert usd_to_bdt(200) == 24800.0


def test_preview_endpoint_is_removed() -> None:
    with _client() as client:
        response = client.post("/api/live/withdraw/preview", headers=AUTH, json={})
        # 404 if no SPA mount; 405 if StaticFiles is mounted at "/" and rejects POST.
        assert response.status_code in (404, 405)
        assert "request_created" not in (response.json() if response.headers.get("content-type", "").startswith("application/json") else {})


def test_valid_crypto_and_p2p_withdrawals() -> None:
    with _client() as client:
        engine = get_trading()
        engine.set_live_balance("withdraw-user", 400)
        before_demo = engine.balance("withdraw-user")

        btc = client.post(
            "/api/live/withdraw",
            headers=AUTH,
            json={"amount": 50, "method": "btc", "address": VALID_BTC, "user_id": "attacker"},
        )
        assert btc.status_code == 200
        assert btc.json()["request_created"] is True
        assert btc.json()["request"]["status"] == STATUS_PENDING
        assert "15 minutes to 7 days" in btc.json()["message"]
        assert "2–12 hours" not in btc.json()["message"]
        assert "guaranteed" not in btc.json()["message"].lower()
        assert "15 minutes to 7 days" in SUBMITTED_MESSAGE
        assert SUBMITTED_MESSAGE == btc.json()["message"]
        assert engine.live_balance("withdraw-user") == 350
        assert engine.balance("withdraw-user") == before_demo

        admin = _admin_headers(client)
        client.post(
            f"/api/admin/withdrawals/{btc.json()['request']['request_id']}/approve",
            headers=admin,
        )

        usdt = client.post(
            "/api/live/withdraw",
            headers=AUTH,
            json={"amount": 60, "method": "usdt_trc20", "address": VALID_TRC20},
        )
        assert usdt.status_code == 200
        client.post(
            f"/api/admin/withdrawals/{usdt.json()['request']['request_id']}/approve",
            headers=admin,
        )

        eth = client.post(
            "/api/live/withdraw",
            headers=AUTH,
            json={"amount": 70, "method": "eth_erc20", "address": VALID_ETH},
        )
        assert eth.status_code == 200
        client.post(
            f"/api/admin/withdrawals/{eth.json()['request']['request_id']}/approve",
            headers=admin,
        )

        bkash = client.post(
            "/api/live/withdraw",
            headers=AUTH,
            json={"amount": 50, "method": "bkash", "payment_details": VALID_BKASH},
        )
        assert bkash.status_code == 200
        assert bkash.json()["request"]["amount_bdt"] == 6200.0
        client.post(
            f"/api/admin/withdrawals/{bkash.json()['request']['request_id']}/approve",
            headers=admin,
        )

        nagad = client.post(
            "/api/live/withdraw",
            headers=AUTH,
            json={"amount": 80, "method": "nagad", "payment_details": VALID_NAGAD},
        )
        assert nagad.status_code == 200
        assert nagad.json()["request"]["amount_bdt"] == 9920.0


def test_limits_and_invalid_details() -> None:
    with _client() as client:
        engine = get_trading()
        engine.set_live_balance("withdraw-user", 12000)
        assert client.post("/api/live/withdraw").status_code == 401

        assert (
            client.post(
                "/api/live/withdraw",
                headers=AUTH,
                json={"amount": 49.99, "method": "btc", "address": VALID_BTC},
            ).json()["detail"]
            == MSG_MIN
        )
        assert (
            client.post(
                "/api/live/withdraw",
                headers=AUTH,
                json={"amount": 10000.01, "method": "btc", "address": VALID_BTC},
            ).json()["detail"]
            == MSG_MAX
        )
        assert (
            client.post(
                "/api/live/withdraw",
                headers=AUTH,
                json={"amount": 40, "method": "bkash", "payment_details": VALID_BKASH},
            ).json()["detail"]
            == MSG_P2P_MIN
        )
        assert (
            client.post(
                "/api/live/withdraw",
                headers=AUTH,
                json={"amount": 404, "method": "nagad", "payment_details": VALID_NAGAD},
            ).json()["detail"]
            == MSG_P2P_MAX
        )
        assert (
            client.post(
                "/api/live/withdraw",
                headers=AUTH,
                json={"amount": 50, "method": "btc", "address": "hello"},
            ).json()["detail"]
            == MSG_BTC
        )
        assert (
            client.post(
                "/api/live/withdraw",
                headers=AUTH,
                json={"amount": 50, "method": "usdt_trc20", "address": "test"},
            ).json()["detail"]
            == MSG_TRC20
        )
        assert (
            client.post(
                "/api/live/withdraw",
                headers=AUTH,
                json={"amount": 50, "method": "eth", "address": "0x12"},
            ).json()["detail"]
            == MSG_ETH
        )
        assert (
            client.post(
                "/api/live/withdraw",
                headers=AUTH,
                json={"amount": 50, "method": "bkash", "payment_details": "123"},
            ).json()["detail"]
            == MSG_BKASH
        )
        assert (
            client.post(
                "/api/live/withdraw",
                headers=AUTH,
                json={"amount": 50, "method": "nagad", "payment_details": "12"},
            ).json()["detail"]
            == MSG_NAGAD
        )
        assert (
            client.post(
                "/api/live/withdraw",
                headers=AUTH,
                json={"amount": 50, "address": VALID_BTC},
            ).json()["detail"]
            == MSG_METHOD
        )
        assert (
            client.post(
                "/api/live/withdraw",
                headers=AUTH,
                json={"amount": 50, "method": "btc", "address": ""},
            ).json()["detail"]
            == MSG_ADDRESS_REQUIRED
        )
        assert (
            client.post(
                "/api/live/withdraw",
                headers=AUTH,
                json={"method": "btc", "address": VALID_BTC},
            ).json()["detail"]
            == MSG_AMOUNT_REQUIRED
        )


def test_insufficient_balance_and_pending_block() -> None:
    with _client() as client:
        engine = get_trading()
        engine.set_live_balance("withdraw-user", 40)
        over = client.post(
            "/api/live/withdraw",
            headers=AUTH,
            json={"amount": 50, "method": "btc", "address": VALID_BTC},
        )
        assert over.json()["detail"] == MSG_INSUFFICIENT

        engine.set_live_balance("withdraw-user", 200)
        first = client.post(
            "/api/live/withdraw",
            headers=AUTH,
            json={"amount": 50, "method": "btc", "address": VALID_BTC},
        )
        assert first.status_code == 200
        assert engine.live_balance("withdraw-user") == 150
        second = client.post(
            "/api/live/withdraw",
            headers=AUTH,
            json={"amount": 50, "method": "btc", "address": VALID_BTC},
        )
        assert second.status_code == 409
        assert second.json()["detail"] == MSG_PENDING
        assert engine.live_balance("withdraw-user") == 150
        listed = client.get("/api/live/withdrawals", headers=AUTH).json()["withdrawals"]
        assert len(listed) == 1
        assert listed[0]["status"] == STATUS_PENDING


def test_approve_reject_idempotent_and_refund() -> None:
    with _client() as client:
        engine = get_trading()
        engine.set_live_balance("withdraw-user", 300)
        admin = _admin_headers(client)
        created = client.post(
            "/api/live/withdraw",
            headers=AUTH,
            json={"amount": 80, "method": "btc", "address": VALID_BTC},
        ).json()["request"]
        request_id = created["request_id"]
        assert engine.live_balance("withdraw-user") == 220

        approved = client.post(f"/api/admin/withdrawals/{request_id}/approve", headers=admin)
        assert approved.status_code == 200
        assert approved.json()["request"]["status"] == STATUS_SUCCESSFUL
        again = client.post(f"/api/admin/withdrawals/{request_id}/approve", headers=admin)
        assert again.status_code == 200
        assert engine.live_balance("withdraw-user") == 220
        reject_after = client.post(
            f"/api/admin/withdrawals/{request_id}/reject",
            headers=admin,
            json={"reason": "too late"},
        )
        assert reject_after.status_code == 409
        assert reject_after.json()["detail"] == MSG_ALREADY_SUCCESSFUL

        second = client.post(
            "/api/live/withdraw",
            headers=AUTH,
            json={"amount": 90, "method": "eth", "address": VALID_ETH},
        ).json()["request"]
        assert engine.live_balance("withdraw-user") == 130
        missing_reason = client.post(
            f"/api/admin/withdrawals/{second['request_id']}/reject",
            headers=admin,
            json={"reason": ""},
        )
        assert missing_reason.json()["detail"] == MSG_REASON_REQUIRED
        rejected = client.post(
            f"/api/admin/withdrawals/{second['request_id']}/reject",
            headers=admin,
            json={"reason": "Please make a deposit before requesting a withdrawal."},
        )
        assert rejected.status_code == 200
        assert rejected.json()["request"]["status"] == STATUS_REJECTED
        assert engine.live_balance("withdraw-user") == 220
        reject_again = client.post(
            f"/api/admin/withdrawals/{second['request_id']}/reject",
            headers=admin,
            json={"reason": "Please make a deposit before requesting a withdrawal."},
        )
        assert reject_again.status_code == 200
        assert engine.live_balance("withdraw-user") == 220
        approve_rejected = client.post(
            f"/api/admin/withdrawals/{second['request_id']}/approve",
            headers=admin,
        )
        assert approve_rejected.status_code == 409
        assert approve_rejected.json()["detail"] == MSG_ALREADY_REJECTED

        history = client.get("/api/live/withdrawals", headers=AUTH).json()["withdrawals"]
        rejected_row = next(item for item in history if item["request_id"] == second["request_id"])
        assert rejected_row["rejection_reason"] == (
            "Please make a deposit before requesting a withdrawal."
        )


def test_user_isolation_and_admin_auth() -> None:
    with _client() as client:
        engine = get_trading()
        engine.set_live_balance("withdraw-user", 200)
        engine.set_live_balance("other-user", 200)
        created = client.post(
            "/api/live/withdraw",
            headers=AUTH,
            json={"amount": 50, "method": "btc", "address": VALID_BTC},
        ).json()["request"]
        request_id = created["request_id"]
        other_list = client.get("/api/live/withdrawals", headers=OTHER).json()["withdrawals"]
        assert other_list == []
        stolen = client.get(f"/api/live/withdrawals/{request_id}", headers=OTHER)
        assert stolen.status_code == 404
        own = client.get(f"/api/live/withdrawals/{request_id}", headers=AUTH)
        assert own.status_code == 200

        assert client.get("/api/admin/withdrawals", headers=AUTH).status_code == 401
        assert client.post(
            f"/api/admin/withdrawals/{request_id}/approve",
            headers=AUTH,
        ).status_code == 401
        assert client.post(
            "/api/admin/login",
            json={"username": "test-admin", "password": "wrong-pass"},
        ).status_code == 401
        admin = _admin_headers(client)
        listed = client.get("/api/admin/withdrawals?status=Pending&search=withdraw-user", headers=admin)
        assert listed.status_code == 200
        assert listed.json()["withdrawals"][0]["request_id"] == request_id


def test_concurrent_withdrawal_protection() -> None:
    with _client() as client:
        engine = get_trading()
        engine.set_live_balance("withdraw-user", 80)

        def _submit() -> int:
            return client.post(
                "/api/live/withdraw",
                headers=AUTH,
                json={"amount": 50, "method": "btc", "address": VALID_BTC},
            ).status_code

        with ThreadPoolExecutor(max_workers=2) as pool:
            codes = list(pool.map(lambda _: _submit(), range(2)))
        assert sorted(codes) == [200, 409]
        assert engine.live_balance("withdraw-user") == 30
        rows = client.get("/api/live/withdrawals", headers=AUTH).json()["withdrawals"]
        assert len(rows) == 1
