from __future__ import annotations

import os
from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

ROOT = Path(__file__).resolve().parents[1]
STATIC = ROOT / "static"

app = FastAPI(title="TradePulseSignal", version="0.1.0")
app.mount("/static", StaticFiles(directory=STATIC), name="static")


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "service": "tradepulse-signal"}


@app.get("/config")
def config() -> dict:
    return {
        "tradepulse_base_url": os.getenv("TRADEPULSE_BASE_URL", "http://127.0.0.1:8000"),
        "asset": "BTC/USD-OTC",
        "has_token": bool(os.getenv("TRADEPULSE_ID_TOKEN", "").strip()),
    }


@app.get("/")
def index() -> FileResponse:
    return FileResponse(STATIC / "index.html")
