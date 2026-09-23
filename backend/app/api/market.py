from fastapi import APIRouter, HTTPException, Query

from app.core.runtime import ensure_market_runtime

router = APIRouter(prefix="/api/market", tags=["market"])


@router.get("/status")
async def market_status() -> dict:
    runtime = await ensure_market_runtime()
    return {
        "state": "LIVE_SIMULATION" if runtime.loop_alive() else "MARKET_OFFLINE",
        "simulated": True,
        "message": "Simulated OTC market. Not a real-money or live-broker feed.",
        "assets": len(runtime.streams),
    }


@router.get("/quotes")
async def market_quotes() -> dict:
    runtime = await ensure_market_runtime()
    return {
        "state": "LIVE_SIMULATION" if runtime.loop_alive() else "MARKET_OFFLINE",
        "simulated": True,
        "quotes": runtime.all_quotes(),
    }


@router.get("/candles")
async def market_candles(
    asset: str = Query(...),
    limit: int = Query(500, ge=1, le=1000),
) -> dict:
    runtime = await ensure_market_runtime()
    if asset not in runtime.streams:
        raise HTTPException(status_code=404, detail="Unknown OTC asset")
    return {
        "asset": asset,
        "timeframe": "1m",
        "simulated": True,
        "candles": runtime.history(asset, limit=limit),
    }
