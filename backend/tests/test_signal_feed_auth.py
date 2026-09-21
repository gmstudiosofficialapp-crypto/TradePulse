import base64
import json
from datetime import datetime, timezone

import pytest
from fastapi.testclient import TestClient
from firebase_admin._token_gen import ExpiredIdTokenError
from firebase_admin.auth import InvalidIdTokenError

from app.core.firebase_auth import (
    set_token_verifier,
    signal_feed_project_ids,
    verify_signal_feed_token,
)
from app.main import create_app
from market_engine.config.assets import ASSET_CONFIGS
from market_engine.config.settings import EngineSettings
from market_engine.services.btc_future_book import BTC_SYMBOL
from market_engine.services.market_runtime import MarketRuntime

WALLET = "wallet-operator"
DESH = "desh-sheba"


def _b64(data: dict) -> str:
    raw = json.dumps(data, separators=(",", ":")).encode("utf-8")
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def _token(project_id: str, uid: str = "user-1", **extra) -> str:
    header = _b64({"alg": "RS256", "kid": "test"})
    payload = {
        "iss": f"https://securetoken.google.com/{project_id}",
        "aud": project_id,
        "sub": uid,
        "uid": uid,
        "email": f"{uid}@example.com",
        "name": "Test User",
        "firebase": {"sign_in_provider": "password"},
        **extra,
    }
    return f"{header}.{_b64(payload)}.signature"


def _payload(token: str) -> dict:
    segment = token.split(".", 2)[1]
    padded = segment + "=" * (-len(segment) % 4)
    return json.loads(base64.urlsafe_b64decode(padded.encode("ascii")))


@pytest.fixture
def trusted_feed(monkeypatch):
    previous = set_token_verifier(None)
    calls: list[str] = []

    def fake_verify(token: str, project_id: str) -> dict:
        calls.append(project_id)
        claims = _payload(token)
        marker = claims.get("marker")
        if marker == "expired":
            raise ExpiredIdTokenError("expired")
        if marker == "bad-signature":
            raise InvalidIdTokenError("bad signature")
        if claims.get("aud") != project_id:
            raise InvalidIdTokenError("audience")
        return claims

    monkeypatch.setenv("FIREBASE_PROJECT_ID", WALLET)
    monkeypatch.setenv("TRUSTED_FIREBASE_PROJECT_IDS", f"{WALLET},{DESH}")
    monkeypatch.setattr("app.core.firebase_auth._admin_verify_project", fake_verify)
    yield calls
    set_token_verifier(previous)


def _client() -> TestClient:
    runtime = MarketRuntime(
        settings=EngineSettings(history_size=2, warmup_ticks_per_minute=2),
        assets=[ASSET_CONFIGS[BTC_SYMBOL]],
    )
    runtime.warmup(datetime(2026, 9, 21, 16, 9, 20, tzinfo=timezone.utc))
    return TestClient(create_app(runtime=runtime, auto_start=False))


def test_project_list_always_keeps_tradepulse_project(monkeypatch) -> None:
    monkeypatch.setenv("FIREBASE_PROJECT_ID", WALLET)
    monkeypatch.delenv("TRUSTED_FIREBASE_PROJECT_IDS", raising=False)
    assert signal_feed_project_ids() == (WALLET,)
    monkeypatch.setenv("TRUSTED_FIREBASE_PROJECT_IDS", f" {DESH} , {DESH} ")
    assert signal_feed_project_ids() == (WALLET, DESH)


def test_existing_tradepulse_token_accepted(trusted_feed) -> None:
    user = verify_signal_feed_token(_token(WALLET, "tp-user"))
    assert user.uid == "tp-user"
    assert trusted_feed == [WALLET]


def test_desh_sheba_token_accepted(trusted_feed) -> None:
    user = verify_signal_feed_token(_token(DESH, "ds-user"))
    assert user.uid == "ds-user"
    assert user.email == "ds-user@example.com"
    assert trusted_feed == [DESH]


def test_expired_token_rejected(trusted_feed) -> None:
    with pytest.raises(Exception) as exc:
        verify_signal_feed_token(_token(DESH, marker="expired"))
    assert getattr(exc.value, "status_code", None) == 401
    assert trusted_feed == [DESH]


def test_invalid_signature_rejected(trusted_feed) -> None:
    with pytest.raises(Exception) as exc:
        verify_signal_feed_token(_token(WALLET, marker="bad-signature"))
    assert getattr(exc.value, "status_code", None) == 401


def test_wrong_project_rejected_without_verification(trusted_feed) -> None:
    with pytest.raises(Exception) as exc:
        verify_signal_feed_token(_token("untrusted-project"))
    assert getattr(exc.value, "status_code", None) == 401
    assert trusted_feed == []


def test_malformed_token_rejected(trusted_feed) -> None:
    with pytest.raises(Exception) as exc:
        verify_signal_feed_token("not-a-jwt")
    assert getattr(exc.value, "status_code", None) == 401
    assert trusted_feed == []


def test_missing_firebase_claims_rejected(trusted_feed) -> None:
    header = _b64({"alg": "RS256", "kid": "test"})
    body = _b64(
        {
            "iss": f"https://securetoken.google.com/{DESH}",
            "aud": DESH,
            "sub": "user-1",
            "uid": "user-1",
        }
    )
    with pytest.raises(Exception) as exc:
        verify_signal_feed_token(f"{header}.{body}.signature")
    assert getattr(exc.value, "status_code", None) == 401


def test_signal_http_accepts_desh_sheba_and_rejects_missing(trusted_feed) -> None:
    with _client() as client:
        missing = client.get("/api/signal/btc-future-book")
        assert missing.status_code == 401
        denied = client.get(
            "/api/signal/btc-future-book",
            headers={"Authorization": "Bearer not-a-jwt"},
        )
        assert denied.status_code == 401
        ok = client.get(
            "/api/signal/btc-future-book",
            headers={"Authorization": f"Bearer {_token(DESH, 'ds-http')}"},
        )
        assert ok.status_code == 200
        assert ok.json()["asset"] == BTC_SYMBOL
        assert ok.json()["type"] == "snapshot"
        tradepulse = client.get(
            "/api/signal/btc-future-book",
            headers={"Authorization": f"Bearer {_token(WALLET, 'tp-http')}"},
        )
        assert tradepulse.status_code == 200


def test_signal_ws_authenticates_desh_sheba_token(trusted_feed) -> None:
    with _client() as client:
        with client.websocket_connect("/ws/signal-btc-future") as ws:
            ws.send_json({"type": "auth", "token": _token(DESH, "ds-ws")})
            assert ws.receive_json()["type"] == "authenticated"
            ws.send_json({"type": "subscribe"})
            snapshot = ws.receive_json()
            assert snapshot["type"] == "snapshot"
            assert snapshot["future_count"] == 3


def test_signal_ws_rejects_missing_auth(trusted_feed) -> None:
    with _client() as client:
        with pytest.raises(Exception):
            with client.websocket_connect("/ws/signal-btc-future") as ws:
                ws.send_json({"type": "subscribe"})
                ws.receive_json()


def test_trading_auth_does_not_accept_desh_sheba_token(monkeypatch) -> None:
    previous = set_token_verifier(None)
    monkeypatch.setattr("app.core.firebase_auth.init_firebase_admin", lambda: None)

    def default_app_only(token, app=None, check_revoked=False, clock_skew_seconds=0):
        claims = _payload(token)
        if claims.get("aud") != WALLET:
            raise InvalidIdTokenError("wrong project")
        return claims

    monkeypatch.setattr("app.core.firebase_auth.auth.verify_id_token", default_app_only)
    try:
        with _client() as client:
            foreign = client.get(
                "/api/demo/balance",
                headers={"Authorization": f"Bearer {_token(DESH, 'ds-trade')}"},
            )
            assert foreign.status_code == 401
            home = client.get(
                "/api/demo/balance",
                headers={"Authorization": f"Bearer {_token(WALLET, 'tp-trade')}"},
            )
            assert home.status_code == 200
            assert home.json()["user_id"] == "tp-trade"
    finally:
        set_token_verifier(previous)


def test_public_market_feed_unchanged(trusted_feed) -> None:
    with _client() as client:
        quotes = client.get("/api/market/quotes")
        assert quotes.status_code == 200
        text = str(quotes.json())
        assert "FUTURE_1" not in text
        assert "schema_version" not in text
        with client.websocket_connect("/ws/market") as ws:
            assert ws.receive_json()["type"] == "status"
            ws.send_json({"type": "subscribe", "asset": BTC_SYMBOL})
            assert ws.receive_json()["type"] == "subscribed"
            quote = ws.receive_json()
            assert quote["type"] == "quote"
            assert "futures" not in quote
