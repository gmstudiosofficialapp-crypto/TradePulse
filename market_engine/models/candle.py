from dataclasses import dataclass
from datetime import datetime


@dataclass(slots=True)
class Candle:
    asset: str
    timeframe: str
    open: float
    high: float
    low: float
    close: float
    volume: int
    open_time: datetime
    close_time: datetime
    closed: bool = False

    def to_dict(self) -> dict:
        return {
            "asset": self.asset,
            "timeframe": self.timeframe,
            "open": self.open,
            "high": self.high,
            "low": self.low,
            "close": self.close,
            "volume": self.volume,
            "open_time": self.open_time.isoformat(),
            "close_time": self.close_time.isoformat(),
            "closed": self.closed,
        }
