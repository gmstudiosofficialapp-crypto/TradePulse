from pathlib import Path

from fastapi.testclient import TestClient

from app.main import ROOT, create_app
from market_engine.config.assets import ASSET_CONFIGS
from market_engine.config.settings import EngineSettings
from market_engine.services.market_runtime import MarketRuntime


def test_fastapi_serves_flutter_build_when_present() -> None:
    web = ROOT / "frontend" / "build" / "web" / "index.html"
    if not web.is_file():
        return
    runtime = MarketRuntime(
        settings=EngineSettings(history_size=4, warmup_ticks_per_minute=2),
        assets=[ASSET_CONFIGS["BTC/USD-OTC"]],
    )
    runtime.warmup()
    with TestClient(create_app(runtime=runtime, auto_start=False)) as client:
        home = client.get("/")
        assert home.status_code == 200
        assert "flutter" in home.text.lower() or "tradepulse" in home.text.lower()
        health = client.get("/health")
        assert health.status_code == 200
        quotes = client.get("/api/market/status")
        assert quotes.status_code == 200
