from fastapi import APIRouter, HTTPException, Query

from app.core.runtime import get_coordinator, get_runtime
from app.services.ground_truth import peek_reference_direction

router = APIRouter(prefix="/api/private", tags=["private-reference"])


@router.get("/reference")
def private_reference(asset: str = Query(...)) -> dict:
    runtime = get_runtime()
    stream = runtime.streams.get(asset)
    if stream is None:
        raise HTTPException(status_code=404, detail="Unknown OTC asset")
    truth = peek_reference_direction(stream)
    cached = get_coordinator().latest_truth.get(asset)
    if cached:
        truth.update({k: cached[k] for k in cached if k not in {"closed_candle"}})
    return truth


@router.get("/btc-future-candles")
def btc_future_candles() -> dict:
    runtime = get_runtime()
    snapshot = runtime.btc_future_snapshot()
    if snapshot.get("live") is None and snapshot.get("future_count", 0) == 0:
        stream = runtime.streams.get("BTC/USD-OTC")
        if stream is None:
            raise HTTPException(status_code=404, detail="BTC/USD-OTC is not enabled")
    return snapshot
