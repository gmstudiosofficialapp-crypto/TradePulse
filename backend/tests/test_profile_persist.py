from fastapi.testclient import TestClient

from app.core.runtime import get_trading
from app.main import create_app
from market_engine.config.assets import ASSET_CONFIGS
from market_engine.config.settings import EngineSettings
from market_engine.services.market_runtime import MarketRuntime

AUTH = {"Authorization": "Bearer profile-user|profile@tradepulse.test"}
OTHER = {"Authorization": "Bearer other-user|other@tradepulse.test"}


def _client() -> TestClient:
    runtime = MarketRuntime(
        settings=EngineSettings(history_size=3, warmup_ticks_per_minute=2),
        assets=[ASSET_CONFIGS["BTC/USD-OTC"]],
    )
    runtime.warmup()
    return TestClient(create_app(runtime=runtime, auto_start=False))


def test_profile_fields_persist_across_rebootstrap() -> None:
    with _client() as client:
        client.post("/api/me", headers=AUTH)
        saved = client.patch(
            "/api/me",
            headers=AUTH,
            json={
                "fullName": "Ada Trader",
                "username": "ada",
                "phone": "01712345678",
                "country": "Bangladesh",
                "division": "Dhaka",
                "user_id": "attacker",
            },
        )
        assert saved.status_code == 200
        user = saved.json()["user"]
        assert user["uid"] == "profile-user"
        assert user["displayName"] == "Ada Trader"
        assert user["username"] == "ada"
        assert user["phone"] == "01712345678"
        assert user["country"] == "Bangladesh"
        assert user["division"] == "Dhaka"

        again = client.post("/api/me", headers=AUTH).json()["user"]
        assert again["username"] == "ada"
        assert again["phone"] == "01712345678"
        assert again["country"] == "Bangladesh"
        assert again["displayName"] == "Ada Trader"

        other = client.get("/api/me", headers=OTHER).json()["user"]
        assert other["uid"] == "other-user"
        assert other.get("username") in (None, "")
        assert get_trading().profile("profile-user")["username"] == "ada"
