from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone

SCHEMA_VERSION = 1
ASSET = "BTC/USD-OTC"
HORIZON = 3
DIRECTIONS = frozenset({"UP", "DOWN", "FLAT"})


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def is_valid_candle(raw: object) -> bool:
    if not isinstance(raw, dict):
        return False
    required = (
        "id",
        "asset",
        "candle_start_time",
        "candle_end_time",
        "open",
        "high",
        "low",
        "close",
        "direction",
    )
    if any(key not in raw for key in required):
        return False
    if raw.get("asset") != ASSET:
        return False
    if raw.get("direction") not in DIRECTIONS:
        return False
    try:
        float(raw["open"])
        float(raw["high"])
        float(raw["low"])
        float(raw["close"])
    except (TypeError, ValueError):
        return False
    return True


def is_valid_envelope(raw: object) -> bool:
    if not isinstance(raw, dict):
        return False
    if raw.get("schema_version") != SCHEMA_VERSION:
        return False
    if raw.get("asset") != ASSET:
        return False
    futures = raw.get("futures")
    if not isinstance(futures, list) or len(futures) != HORIZON:
        return False
    if raw.get("live") is not None and not is_valid_candle(raw["live"]):
        return False
    return all(is_valid_candle(item) for item in futures)


@dataclass
class BtcFutureState:
    connected: bool = False
    last_update: str | None = None
    last_sequence: int = 0
    live: dict | None = None
    futures: list[dict] = field(default_factory=list)
    last_error: str | None = None
    last_event: str | None = None
    reject_count: int = 0

    def apply(self, message: object, *, allow_snapshot_reset: bool = False) -> bool:
        if not isinstance(message, dict):
            self.last_error = "malformed"
            self.reject_count += 1
            return False
        kind = message.get("type")
        if kind in {"authenticated", "pong", "error", "unsubscribed"}:
            if kind == "error":
                self.last_error = str(message.get("message") or "error")
            return True
        if not is_valid_envelope(message):
            self.last_error = "invalid_envelope"
            self.reject_count += 1
            return False
        sequence = int(message.get("sequence") or 0)
        if kind != "snapshot" and sequence <= self.last_sequence:
            self.last_error = "stale_sequence"
            self.reject_count += 1
            return False
        if kind == "snapshot" and not allow_snapshot_reset and sequence < self.last_sequence:
            self.last_error = "stale_snapshot"
            self.reject_count += 1
            return False
        self.live = message.get("live")
        self.futures = list(message.get("futures") or [])
        self.last_sequence = max(self.last_sequence, sequence)
        self.last_update = str(message.get("generated_at") or _utc_now())
        self.last_event = str(kind)
        self.last_error = None
        self.reject_count = 0
        return True

    def mark_connected(self, connected: bool) -> None:
        self.connected = connected
        if not connected:
            self.last_event = "disconnected"

    def needs_resync(self) -> bool:
        return self.reject_count >= 3

    def to_view(self) -> dict:
        return {
            "asset": ASSET,
            "connected": self.connected,
            "last_update": self.last_update,
            "last_event": self.last_event,
            "last_error": self.last_error,
            "sequence": self.last_sequence,
            "live": self.live,
            "futures": self.futures,
        }
