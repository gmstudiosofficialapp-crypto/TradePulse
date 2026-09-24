from fastapi.testclient import TestClient

from app.core.runtime import get_trading
from app.main import create_app
from app.services.withdraw import (
    DEPOSIT_REQUIRED_MESSAGE,
    MSG_ADDRESS_REQUIRED,
    MSG_BTC,
    MSG_ETH,
    MSG_INSUFFICIENT,
    MSG_MAX,
    MSG_METHOD,
    MSG_MIN,
    MSG_TRC20,
    parse_amount,
    preview_withdrawal,
    validate_btc_address,
    validate_eth_address,
    validate_trc20_address,
    verified_deposit_total,
)
from market_engine.config.assets import ASSET_CONFIGS
from market_engine.config.settings import EngineSettings
from market_engine.services.market_runtime import MarketRuntime

AUTH = {"Authorization": "Bearer withdraw-user|withdraw@tradepulse.test"}
VALID_BTC = "1CUXN4MrQ9qyZBtqU6Pg4U7iZiy6Y3ztMt"
VALID_TRC20 = "THfnsscby3ZW3LPGbTyGLyLkFsFdRwV5Xq"
VALID_ETH = "0x27e711D1B6E4866EBf7904B3B631f6D05518E1B6"


def _client() -> TestClient:
    runtime = MarketRuntime(
        settings=EngineSettings(history_size=4, warmup_ticks_per_minute=2),
        assets=[ASSET_CONFIGS["BTC/USD-OTC"]],
    )
    runtime.warmup()
    return TestClient(create_app(runtime=runtime, auto_start=False))


def test_amount_bounds() -> None:
    assert parse_amount(49.99) == MSG_MIN
    assert parse_amount(50) == 50.0
    assert parse_amount(10_000) == 10_000.0
    assert parse_amount(10_000.01) == MSG_MAX


def test_address_format_validation() -> None:
    assert validate_btc_address(VALID_BTC)
    assert validate_btc_address("3J98t1WpEZ73CNmYviecrnyiWrnqRhWNLy")
    assert validate_btc_address("bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4")
    assert not validate_btc_address("abc")
    assert not validate_btc_address("12")
    assert not validate_btc_address("hello")
    assert not validate_btc_address("12345")
    assert not validate_btc_address("0x27e711D1B6E4866EBf7904B3B631f6D05518E1B6")

    assert validate_trc20_address(VALID_TRC20)
    assert not validate_trc20_address("Tshort")
    assert not validate_trc20_address("abc")
    assert not validate_trc20_address(VALID_BTC)

    assert validate_eth_address(VALID_ETH)
    assert not validate_eth_address("0x12")
    assert not validate_eth_address("0xabc")
    assert not validate_eth_address("hello")
    assert not validate_eth_address("12345")


def test_preview_rejects_invalid_fields_without_writing() -> None:
    live = 500.0
    assert preview_withdrawal(
        user_id="u", live_balance=live, amount=49.99, method="btc", address=VALID_BTC
    )["message"] == MSG_MIN
    assert preview_withdrawal(
        user_id="u", live_balance=live, amount=100, method=None, address=VALID_BTC
    )["message"] == MSG_METHOD
    assert preview_withdrawal(
        user_id="u", live_balance=live, amount=100, method="btc", address=""
    )["message"] == MSG_ADDRESS_REQUIRED
    assert preview_withdrawal(
        user_id="u", live_balance=live, amount=100, method="btc", address="abc"
    )["message"] == MSG_BTC
    assert preview_withdrawal(
        user_id="u", live_balance=live, amount=100, method="usdt_trc20", address="test"
    )["message"] == MSG_TRC20
    assert preview_withdrawal(
        user_id="u", live_balance=live, amount=100, method="eth", address="0x12"
    )["message"] == MSG_ETH
    assert preview_withdrawal(
        user_id="u", live_balance=40, amount=50, method="btc", address=VALID_BTC
    )["message"] == MSG_INSUFFICIENT


def test_valid_preview_reaches_deposit_gate() -> None:
    result = preview_withdrawal(
        user_id="u",
        live_balance=200,
        amount=100,
        method="btc",
        address=VALID_BTC,
    )
    assert result["form_valid"] is True
    assert result["reason"] == "deposit_required"
    assert result["request_created"] is False
    assert result["balance_deducted"] is False
    assert result["deposit_recorded"] is False
    assert result["message"] == DEPOSIT_REQUIRED_MESSAGE
    assert verified_deposit_total("u") is None


def test_api_validates_server_side_and_does_not_create_records() -> None:
    with _client() as client:
        engine = get_trading()
        engine.set_live_balance("withdraw-user", 250)
        before_live = engine.live_balance("withdraw-user")
        before_demo = engine.balance("withdraw-user")
        before_txns = list(engine.transactions.list_for_user("withdraw-user"))

        assert client.post("/api/live/withdraw/preview").status_code == 401

        too_small = client.post(
            "/api/live/withdraw/preview",
            headers=AUTH,
            json={"amount": 49.99, "method": "btc", "address": VALID_BTC, "user_id": "attacker"},
        )
        assert too_small.status_code == 400
        assert too_small.json()["detail"] == MSG_MIN

        too_big = client.post(
            "/api/live/withdraw/preview",
            headers=AUTH,
            json={"amount": 10000.01, "method": "btc", "address": VALID_BTC},
        )
        assert too_big.json()["detail"] == MSG_MAX

        over_balance = client.post(
            "/api/live/withdraw/preview",
            headers=AUTH,
            json={"amount": 251, "method": "btc", "address": VALID_BTC},
        )
        assert over_balance.json()["detail"] == MSG_INSUFFICIENT

        no_method = client.post(
            "/api/live/withdraw/preview",
            headers=AUTH,
            json={"amount": 50, "address": VALID_BTC},
        )
        assert no_method.json()["detail"] == MSG_METHOD

        no_address = client.post(
            "/api/live/withdraw/preview",
            headers=AUTH,
            json={"amount": 50, "method": "btc", "address": ""},
        )
        assert no_address.json()["detail"] == MSG_ADDRESS_REQUIRED

        short = client.post(
            "/api/live/withdraw/preview",
            headers=AUTH,
            json={"amount": 50, "method": "btc", "address": "hello"},
        )
        assert short.json()["detail"] == MSG_BTC

        accepted = client.post(
            "/api/live/withdraw/preview",
            headers=AUTH,
            json={"amount": 50, "method": "btc", "address": VALID_BTC, "user_id": "attacker"},
        )
        assert accepted.status_code == 200
        body = accepted.json()
        assert body["reason"] == "deposit_required"
        assert body["request_created"] is False
        assert body["balance_deducted"] is False
        assert body["deposit_recorded"] is False
        assert body["message"] == DEPOSIT_REQUIRED_MESSAGE

        ten_k = client.post(
            "/api/live/withdraw/preview",
            headers=AUTH,
            json={"amount": 10000, "method": "eth_erc20", "address": VALID_ETH},
        )
        assert ten_k.status_code == 400
        assert ten_k.json()["detail"] == MSG_INSUFFICIENT

        engine.set_live_balance("withdraw-user", 10000)
        top = client.post(
            "/api/live/withdraw/preview",
            headers=AUTH,
            json={"amount": 10000, "method": "usdt_trc20", "address": VALID_TRC20},
        )
        assert top.status_code == 200
        assert top.json()["reason"] == "deposit_required"

        assert engine.live_balance("withdraw-user") == 10000.0
        assert engine.balance("withdraw-user") == before_demo
        assert engine.transactions.list_for_user("withdraw-user") == before_txns
        assert engine.live_balance("withdraw-user") != before_live or before_live == 10000.0
        assert verified_deposit_total("withdraw-user") is None
