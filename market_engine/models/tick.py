from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True, slots=True)
class Tick:
    asset: str
    timestamp: datetime
    price: float

    def to_dict(self) -> dict:
        return {
            "asset": self.asset,
            "timestamp": self.timestamp.isoformat(),
            "price": self.price,
        }
