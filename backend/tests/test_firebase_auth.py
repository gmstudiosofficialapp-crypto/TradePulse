from fastapi.testclient import TestClient

from app.core.firebase_auth import FirebaseUser, require_user, set_token_verifier, verify_id_token
from app.main import create_app
from app.persistence.memory import MemoryAccountStore, MemoryLedger, MemoryTradeStore, MemoryTransactionStore
from app.services.demo_trading import DemoTradingEngine
from market_engine.config.assets import ASSET_CONFIGS
from market_engine.config.settings import EngineSettings
from market_engine.services.market_runtime import MarketRuntime


def _client() -> TestClient:
    runtime = MarketRuntime(
        settings=EngineSettings(history_size=8, warmup_ticks_per_minute=2),
        assets=[ASSET_CONFIGS["BTC/USD-OTC"]],
    )
    runtime.warmup()
    return TestClient(create_app(runtime=runtime, auto_start=False))


def test_verify_extracts_uid() -> None:
    user = verify_id_token("abc|ada@example.com")
    assert user.uid == "abc"
    assert user.email == "ada@example.com"


def test_unauthenticated_balance_rejected() -> None:
    with _client() as client:
        response = client.get("/api/demo/balance")
        assert response.status_code == 401


def test_invalid_token_rejected() -> None:
    with _client() as client:
        response = client.get(
            "/api/demo/balance",
            headers={"Authorization": "Bearer invalid"},
        )
        assert response.status_code == 401


def test_user_and_account_created() -> None:
    with _client() as client:
        created = client.post(
            "/api/me",
            headers={"Authorization": "Bearer uid1|one@example.com"},
        )
        assert created.status_code == 200
        body = created.json()
        assert body["user"]["uid"] == "uid1"
        assert body["balance"] == 10000.0
        assert body["live_balance"] == 10.0
        assert body["signup_bonus_granted"] is True
        assert body["signup_bonus_just_granted"] is True
        again = client.get(
            "/api/demo/balance",
            headers={"Authorization": "Bearer uid1|one@example.com"},
        )
        assert again.json()["balance"] == 10000.0


def test_trade_uses_token_uid_not_body() -> None:
    with _client() as client:
        opened = client.post(
            "/api/demo/trades",
            headers={"Authorization": "Bearer uid2|two@example.com"},
            json={"asset": "BTC/USD-OTC", "direction": "BUY", "stake": 10, "user_id": "attacker"},
        )
        assert opened.status_code == 200
        assert opened.json()["user_id"] == "uid2"
        other = client.get(
            "/api/demo/trades",
            headers={"Authorization": "Bearer uid3|three@example.com"},
        )
        assert other.json()["trades"] == []


def test_insufficient_balance_api() -> None:
    with _client() as client:
        headers = {"Authorization": "Bearer uid4|four@example.com"}
        first = client.post(
            "/api/demo/trades",
            headers=headers,
            json={"asset": "BTC/USD-OTC", "direction": "BUY", "stake": 10000},
        )
        assert first.status_code == 200
        second = client.post(
            "/api/demo/trades",
            headers=headers,
            json={"asset": "BTC/USD-OTC", "direction": "BUY", "stake": 1},
        )
        assert second.status_code == 400


def test_shared_store_survives_engine_restart() -> None:
    accounts = MemoryAccountStore(10000)
    trades = MemoryTradeStore()
    txns = MemoryTransactionStore()
    first = DemoTradingEngine(
        accounts=accounts,
        trades=trades,
        transactions=txns,
        ledger=MemoryLedger(accounts, trades, txns),
    )
    trade = first.open_trade("uid5", "BTC/USD-OTC", "BUY", 10, 100)
    first.settle(trade["trade_id"], 110)
    second = DemoTradingEngine(
        accounts=accounts,
        trades=trades,
        transactions=txns,
        ledger=MemoryLedger(accounts, trades, txns),
    )
    assert second.balance("uid5") == 10009.2
    assert second.trades.list_for_user("uid5")[0]["result"] == "WIN"
    assert second.transactions.list_for_user("uid5")


def test_require_user_dependency() -> None:
    set_token_verifier(lambda token: FirebaseUser(uid="dep", email="dep@example.com"))
    try:
        user = require_user(authorization="Bearer anything")
        assert user.uid == "dep"
    finally:
        from fastapi import HTTPException

        def _restore(token: str) -> FirebaseUser:
            if token.startswith("invalid") or token == "expired":
                raise HTTPException(status_code=401, detail="Invalid or expired token")
            if "|" in token:
                uid, email = token.split("|", 1)
                return FirebaseUser(uid=uid, email=email, name="Test User")
            return FirebaseUser(uid=token, email=f"{token}@example.com", name="Test User")

        set_token_verifier(_restore)


def _unsigned_firebase_jwt(uid: str, email: str) -> str:
    import base64
    import json

    def _part(data: dict) -> str:
        raw = json.dumps(data, separators=(",", ":")).encode("utf-8")
        return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")

    header = _part({"alg": "none", "typ": "JWT"})
    payload = _part(
        {
            "aud": "wallet-operator",
            "iss": "https://securetoken.google.com/wallet-operator",
            "uid": uid,
            "sub": uid,
            "email": email,
            "firebase": {"sign_in_provider": "password"},
        }
    )
    return f"{header}.{payload}.sig"


def test_memory_local_accepts_firebase_jwt_without_admin(monkeypatch) -> None:
    monkeypatch.delenv("RENDER", raising=False)
    monkeypatch.setenv("TRADEPULSE_PERSISTENCE", "memory")
    previous = set_token_verifier(None)
    try:
        user = verify_id_token(_unsigned_firebase_jwt("bonus-user", "bonus@tradepulse.test"))
        assert user.uid == "bonus-user"
        assert user.email == "bonus@tradepulse.test"
    finally:
        set_token_verifier(previous)
