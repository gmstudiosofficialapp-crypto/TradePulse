from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from app.core.firebase_auth import AuthUser, FirebaseUser
from app.core.runtime import (
    ensure_market_runtime,
    get_admin,
    get_coordinator,
    get_runtime,
    get_signals,
    get_trading,
)
from app.services.demo_trading import BOOK_LIVE
from app.services.leaderboard import build_daily_leaderboard

router = APIRouter(prefix="/api", tags=["demo"])


class OpenTradeBody(BaseModel):
    asset: str
    direction: str
    stake: float = Field(ge=1, le=10000)
    expiry_seconds: int | None = None
    live: bool = False


class DemoCreditBody(BaseModel):
    amount: float = Field(gt=0, le=1_000_000)


class ProfileBody(BaseModel):
    fullName: str | None = None
    username: str | None = None
    phone: str | None = None
    dateOfBirth: str | None = None
    gender: str | None = None
    country: str | None = None
    division: str | None = None
    district: str | None = None
    thana: str | None = None
    city: str | None = None
    area: str | None = None
    fullAddress: str | None = None
    postalCode: str | None = None


def _bootstrap(user: FirebaseUser) -> None:
    get_trading().ensure_account(user.uid, email=user.email, name=user.name)


@router.get("/config")
def public_config() -> dict:
    return get_admin().public_view()


@router.get("/me")
def get_me(user: AuthUser) -> dict:
    _bootstrap(user)
    profile = get_trading().profile(user.uid) or {
        "uid": user.uid,
        "email": user.email,
        "displayName": user.name,
    }
    return {
        "user": profile,
        "balance": get_trading().balance(user.uid),
        "live_balance": get_trading().live_balance(user.uid),
        "simulated": True,
        "account_type": "DEMO",
    }


@router.post("/me")
def bootstrap_me(user: AuthUser) -> dict:
    return get_me(user)


@router.patch("/me")
def update_me(body: ProfileBody, user: AuthUser) -> dict:
    _bootstrap(user)
    fields = {key: value for key, value in body.model_dump().items() if value is not None}
    if "fullName" in fields:
        fields["displayName"] = fields.pop("fullName")
    profile = get_trading().update_profile(user.uid, fields)
    return {"user": profile}


@router.get("/demo/balance")
def demo_balance(user: AuthUser) -> dict:
    _bootstrap(user)
    return {
        "user_id": user.uid,
        "balance": get_trading().balance(user.uid),
        "simulated": True,
        "account_type": "DEMO",
    }


@router.post("/demo/credit")
def demo_credit(body: DemoCreditBody, user: AuthUser) -> dict:
    _bootstrap(user)
    try:
        balance = get_trading().credit_demo(user.uid, body.amount)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return {
        "user_id": user.uid,
        "balance": balance,
        "credited": round(body.amount, 2),
        "simulated": True,
        "account_type": "DEMO",
    }


@router.get("/demo/statistics")
def demo_statistics(user: AuthUser) -> dict:
    _bootstrap(user)
    return get_trading().statistics(user.uid)


@router.get("/demo/trades")
def demo_trades(user: AuthUser) -> dict:
    _bootstrap(user)
    return {"trades": get_trading().listed_trades(user.uid), "simulated": True}


@router.get("/demo/transactions")
def demo_transactions(user: AuthUser) -> dict:
    _bootstrap(user)
    return {"transactions": get_trading().transactions.list_for_user(user.uid), "simulated": True}


@router.get("/live/balance")
def live_balance(user: AuthUser) -> dict:
    _bootstrap(user)
    return {
        "user_id": user.uid,
        "balance": get_trading().live_balance(user.uid),
        "account_type": BOOK_LIVE,
    }


@router.get("/live/trades")
def live_trades(user: AuthUser) -> dict:
    _bootstrap(user)
    return {"trades": get_trading().listed_trades(user.uid, BOOK_LIVE), "account_type": BOOK_LIVE}


@router.get("/live/statistics")
def live_statistics(user: AuthUser) -> dict:
    _bootstrap(user)
    return get_trading().statistics(user.uid, BOOK_LIVE)


@router.get("/live/transactions")
def live_transactions(user: AuthUser) -> dict:
    _bootstrap(user)
    rows = [
        item
        for item in get_trading().transactions.list_for_user(user.uid)
        if item.get("account_type") == BOOK_LIVE
    ]
    return {"transactions": rows, "account_type": BOOK_LIVE}


@router.get("/leaderboard")
def daily_leaderboard(day: str | None = None) -> dict:
    try:
        return build_daily_leaderboard(day)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/demo/trades")
async def open_demo_trade(body: OpenTradeBody, user: AuthUser) -> dict:
    _bootstrap(user)
    runtime = await ensure_market_runtime()
    if body.asset not in runtime.streams:
        raise HTTPException(status_code=404, detail="Unknown OTC asset")
    quote = runtime.quotes.get(body.asset)
    if quote is None:
        raise HTTPException(status_code=409, detail="No live simulated price")
    try:
        trade = get_trading().open_trade(
            user_id=user.uid,
            asset=body.asset,
            direction=body.direction.upper(),
            stake=body.stake,
            entry_price=quote.price,
            expiry_seconds=body.expiry_seconds,
            live=body.live,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    book = trade.get("account_type") or "DEMO"
    await get_coordinator()._emit(
        {
            "type": "trade_opened",
            "user_id": user.uid,
            "asset": trade["asset"],
            "account_type": book,
            "trade": trade,
        }
    )
    await get_coordinator()._emit(
        {
            "type": "balance_updated",
            "user_id": user.uid,
            "account_type": book,
            "balance": get_trading().book_balance(user.uid, book),
        }
    )
    return trade


@router.get("/signals")
def list_signals(asset: str) -> dict:
    runtime = get_runtime()
    if asset not in runtime.streams:
        raise HTTPException(status_code=404, detail="Unknown OTC asset")
    engine = get_signals()
    rows = [item.to_dict() for item in engine.directional_for(asset)]
    rows.sort(key=lambda item: item["generated_at"])
    return {
        "asset": asset,
        "signals": rows,
        "active_count": len(engine.active_for(asset)),
        "max_active": engine.settings.max_active_per_asset,
        "simulated": True,
    }


@router.get("/signals/latest")
def latest_signal(asset: str) -> dict:
    runtime = get_runtime()
    if asset not in runtime.streams:
        raise HTTPException(status_code=404, detail="Unknown OTC asset")
    coordinator = get_coordinator()
    return {
        "asset": asset,
        "signal": coordinator.banner_for(asset),
        "active_count": len(get_signals().active_for(asset)),
        "max_active": get_signals().settings.max_active_per_asset,
        "simulated": True,
    }
