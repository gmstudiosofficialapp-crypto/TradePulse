import json

import pytest

from app.core.firebase_admin_app import FirebaseAdminConfigError, parse_service_account_json
from app.core.safety import LIVE_TRADING_ENABLED

def test_render_rejects_memory_persistence(monkeypatch) -> None:
    monkeypatch.setenv("RENDER", "true")
    monkeypatch.setenv("TRADEPULSE_PERSISTENCE", "memory")
    from app.core.admin_config import AdminMarketControl
    from app.main import _trading_engine

    with pytest.raises(RuntimeError, match="firestore"):
        _trading_engine(AdminMarketControl())



def test_live_trading_stays_disabled() -> None:
    assert LIVE_TRADING_ENABLED is False


def test_service_account_json_rejects_garbage() -> None:
    with pytest.raises(FirebaseAdminConfigError, match="not valid JSON"):
        parse_service_account_json("{not-json")


def test_service_account_json_requires_private_key() -> None:
    with pytest.raises(FirebaseAdminConfigError, match="service-account"):
        parse_service_account_json(json.dumps({"type": "service_account"}))


def test_service_account_json_accepts_object() -> None:
    payload = {
        "type": "service_account",
        "project_id": "wallet-operator",
        "private_key": "-----BEGIN PRIVATE KEY-----\\nTEST\\n-----END PRIVATE KEY-----\\n",
        "client_email": "firebase-adminsdk@wallet-operator.iam.gserviceaccount.com",
    }
    parsed = parse_service_account_json(json.dumps(payload))
    assert parsed["project_id"] == "wallet-operator"
    assert "private_key" in parsed
