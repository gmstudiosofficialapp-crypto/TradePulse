from dataclasses import dataclass
from datetime import datetime
from typing import Literal

Direction = Literal["BUY", "SELL", "NO_SIGNAL"]
SignalStatus = Literal[
    "WAITING",
    "SIGNAL_CREATED",
    "ACTIVE",
    "HOLD",
    "CLOSED",
    "EXPIRED",
    "WIN",
    "LOSS",
    "DRAW",
]


@dataclass(slots=True)
class Signal:
    signal_id: str
    asset: str
    direction: Direction
    generated_at: datetime
    entry_price: float
    expiry_time: datetime
    confidence: float
    status: SignalStatus
    source: str
    timeframe: str = "1m"
    expiry_seconds: int = 60
    candle_open_time: datetime | None = None
    expiry_price: float | None = None
    close_price: float | None = None
    closed_at: datetime | None = None
    result: str | None = None

    def to_dict(self) -> dict:
        return {
            "signal_id": self.signal_id,
            "asset": self.asset,
            "direction": self.direction,
            "generated_at": self.generated_at.isoformat(),
            "entry_price": self.entry_price,
            "expiry_time": self.expiry_time.isoformat(),
            "confidence": round(self.confidence, 4),
            "status": self.status,
            "source": self.source,
            "timeframe": self.timeframe,
            "expiry_seconds": self.expiry_seconds,
            "expiry_price": self.expiry_price,
            "close_price": self.close_price,
            "closed_at": self.closed_at.isoformat() if self.closed_at else None,
            "result": self.result,
            "candle_open_time": self.candle_open_time.isoformat()
            if self.candle_open_time
            else None,
        }
