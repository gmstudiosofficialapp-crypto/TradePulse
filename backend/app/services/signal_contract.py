from __future__ import annotations

from datetime import datetime, timezone

from market_engine.services.btc_future_book import BTC_SYMBOL

SCHEMA_VERSION = 1
TIMEFRAME = "1m"
TIMEZONE = "UTC"
HORIZON = 3
VALID_DIRECTIONS = frozenset({"UP", "DOWN", "FLAT"})


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def candle_id(start_time: str, asset: str = BTC_SYMBOL) -> str:
    return f"{asset}|{TIMEFRAME}|{start_time}"


def _normalize_candle(raw: dict, role: str, *, precomputed: bool) -> dict | None:
    start = raw.get("candle_start_time")
    end = raw.get("candle_end_time")
    direction = raw.get("direction")
    if not start or not end or direction not in VALID_DIRECTIONS:
        return None
    try:
        payload = {
            "id": candle_id(str(start), str(raw.get("asset") or BTC_SYMBOL)),
            "asset": raw.get("asset") or BTC_SYMBOL,
            "timeframe": TIMEFRAME,
            "role": role,
            "candle_start_time": start,
            "candle_end_time": end,
            "open": float(raw["open"]),
            "high": float(raw["high"]),
            "low": float(raw["low"]),
            "close": float(raw["close"]),
            "direction": direction,
            "volume": int(raw.get("volume") or 0),
            "closed": bool(raw.get("closed", precomputed)),
            "precomputed": precomputed,
            "simulated": True,
        }
    except (KeyError, TypeError, ValueError):
        return None
    return payload


def build_signal_payload(
    snapshot: dict,
    *,
    message_type: str,
    sequence: int,
    closed: dict | None = None,
    generated_at: str | None = None,
) -> dict | None:
    live_raw = snapshot.get("live")
    futures_raw = snapshot.get("futures") or []
    if not isinstance(futures_raw, list) or len(futures_raw) != HORIZON:
        return None
    live = None if live_raw is None else _normalize_candle(live_raw, "LIVE", precomputed=False)
    futures = []
    for index, item in enumerate(futures_raw, start=1):
        if not isinstance(item, dict):
            return None
        candle = _normalize_candle(item, f"FUTURE_{index}", precomputed=True)
        if candle is None:
            return None
        futures.append(candle)
    body = {
        "schema_version": SCHEMA_VERSION,
        "type": message_type,
        "asset": BTC_SYMBOL,
        "timeframe": TIMEFRAME,
        "timezone": TIMEZONE,
        "sequence": sequence,
        "generated_at": generated_at or utc_now_iso(),
        "live": live,
        "futures": futures,
        "future_count": len(futures),
        "rolling": True,
    }
    if message_type == "roll" and live is not None:
        body["closed_live_id"] = candle_id(
            str((closed or {}).get("candle_start_time") or "")
        ) if closed else None
        if closed:
            closed_norm = _normalize_candle(closed, "CLOSED", precomputed=False)
            if closed_norm is not None:
                closed_norm["closed"] = True
                body["closed_live"] = closed_norm
        body["promoted_live_id"] = live["id"]
        body["new_future_id"] = futures[-1]["id"]
    return body
