from __future__ import annotations

import os
import sys
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from starlette.responses import FileResponse

ROOT = Path(__file__).resolve().parents[2]

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from app.api.market import router as market_router
from app.api.private import router as private_router
from app.api.signal import router as signal_router
from app.api.trading import router as trading_router
from app.api.ws import attach_hub, router as ws_router
from app.core.admin_config import AdminMarketControl
from app.core.runtime import set_phase3, set_runtime
from app.services.coordinator import Phase3Coordinator
from app.services.demo_trading import DemoTradingEngine
from market_engine.config.settings import EngineSettings
from market_engine.services.market_runtime import MarketRuntime
from signal_engine.services.engine import SignalEngine


def _settings() -> EngineSettings:
    return EngineSettings(
        history_size=int(os.getenv("TRADEPULSE_HISTORY", "500")),
        warmup_ticks_per_minute=int(os.getenv("TRADEPULSE_WARMUP_TICKS", "8")),
    )


def _trading_engine(admin: AdminMarketControl) -> DemoTradingEngine:
    mode = os.getenv("TRADEPULSE_PERSISTENCE", "firestore").strip().lower()
    if os.getenv("RENDER") and mode != "firestore":
        raise RuntimeError(
            "TRADEPULSE_PERSISTENCE must be firestore in production. "
            "Memory fallback is disabled on Render."
        )
    if mode == "memory":
        return DemoTradingEngine(settings=admin.trading)
    from app.core.firebase_admin_app import init_firebase_admin
    from app.persistence.firestore_store import build_firestore_stores

    init_firebase_admin()
    accounts, trades, transactions, ledger = build_firestore_stores(admin.trading.initial_balance)
    return DemoTradingEngine(
        settings=admin.trading,
        accounts=accounts,
        trades=trades,
        transactions=transactions,
        ledger=ledger,
    )


def create_app(
    runtime: MarketRuntime | None = None,
    auto_start: bool = True,
) -> FastAPI:
    engine = runtime or MarketRuntime(settings=_settings())
    admin = AdminMarketControl()
    signals = SignalEngine()
    trading = _trading_engine(admin)
    coordinator = Phase3Coordinator(engine, signals, trading)
    @asynccontextmanager
    async def lifespan(_: FastAPI):
        set_runtime(engine)
        set_phase3(signals, trading, coordinator, admin)
        attach_hub()
        if auto_start:
            await engine.start()
        try:
            yield
        finally:
            await engine.stop()

    application = FastAPI(
        title="TradePulse API",
        description="OTC demo simulator API. Simulated market only. LIVE_TRADING_ENABLED=false.",
        version="0.3.0",
        lifespan=lifespan,
    )
    application.add_middleware(
        CORSMiddleware,
        allow_origins=[
            origin.strip()
            for origin in os.getenv("CORS_ALLOW_ORIGINS", "*").split(",")
            if origin.strip()
        ],
        allow_methods=["*"],
        allow_headers=["*"],
        allow_credentials=False,
    )
    application.include_router(market_router)
    application.include_router(trading_router)
    application.include_router(private_router)
    application.include_router(signal_router)
    application.include_router(ws_router)

    @application.get("/health")
    def health() -> dict[str, str]:
        return {"status": "ok", "service": "tradepulse-backend"}

    web_dir = ROOT / "frontend" / "build" / "web"
    if web_dir.is_dir() and (web_dir / "index.html").exists():

        @application.get("/")
        def public_site() -> FileResponse:
            return FileResponse(web_dir / "index.html")

        application.mount(
            "/",
            StaticFiles(directory=web_dir, html=True),
            name="public_web",
        )

    return application


app = create_app()
