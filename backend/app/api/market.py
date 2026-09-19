from fastapi import APIRouter, HTTPException, Query

from app.core.runtime import get_runtime

router = APIRouter(prefix="/api/market", tags=["market"])


@router.get("/status")
def market_status() -> dict:
    runtime = get_runtime()
    return {
        "state": "LIVE_SIMULATION" if runtime.running else "MARKET_OFFLINE",
        "simulated": True,
        "message": "Simulated OTC market. Not a real-money or live-broker feed.",
        "assets": len(runtime.streams),
    }


@router.get("/quotes")
def market_quotes() -> dict:
    runtime = get_runtime()
    return {
        "state": "LIVE_SIMULATION" if runtime.running else "MARKET_OFFLINE",
        "simulated": True,
        "quotes": runtime.all_quotes(),
    }


@router.get("/candles")
def market_candles(
    asset: str = Query(...),
    limit: int = Query(500, ge=1, le=1000),
) -> dict:
    runtime = get_runtime()
    if asset not in runtime.streams:
        raise HTTPException(status_code=404, detail="Unknown OTC asset")
    return {
        "asset": asset,
        "timeframe": "1m",
        "simulated": True,
        "candles": runtime.history(asset, limit=limit),
    }
