from app.core.runtime import get_trading
from app.main import create_app
from app.services.leaderboard import build_daily_leaderboard
from fastapi.testclient import TestClient
from market_engine.config.assets import ASSET_CONFIGS
from market_engine.config.settings import EngineSettings
from market_engine.services.market_runtime import MarketRuntime


def test_daily_leaderboard_is_deterministic_and_display_only() -> None:
    first = build_daily_leaderboard("2026-09-24")
    again = build_daily_leaderboard("2026-09-24")
    other = build_daily_leaderboard("2026-09-25")
    assert first == again
    assert first["badge"] == "TOP 100"
    assert len(first["entries"]) == 100
    wins = [item["todays_win"] for item in first["entries"]]
    assert wins == sorted(wins, reverse=True)
    assert all(isinstance(value, int) for value in wins)
    assert all(1000 <= value <= 1_000_000 for value in wins)
    assert first["entries"][0]["rank"] == 1
    assert first["entries"][-1]["rank"] == 100
    assert [item["todays_win"] for item in other["entries"]] != wins

    runtime = MarketRuntime(
        settings=EngineSettings(history_size=3, warmup_ticks_per_minute=2),
        assets=[ASSET_CONFIGS["BTC/USD-OTC"]],
    )
    runtime.warmup()
    with TestClient(create_app(runtime=runtime, auto_start=False)) as client:
        before_balance = get_trading().balance("user-a")
        before_live = get_trading().live_balance("user-a")
        before_trades = list(get_trading().trades.list_for_user("user-a"))
        payload = client.get("/api/leaderboard", params={"day": "2026-09-24"}).json()
        assert payload["entries"] == first["entries"]
        assert get_trading().balance("user-a") == before_balance
        assert get_trading().live_balance("user-a") == before_live
        assert get_trading().trades.list_for_user("user-a") == before_trades
        denied = client.get("/api/live/balance")
        assert denied.status_code == 401
