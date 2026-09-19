from dataclasses import dataclass


@dataclass(slots=True)
class PriceState:
    asset: str
    price: float
    momentum: float = 0.0
    regime: int = 0
    regime_ticks_left: int = 40
    last_return: float = 0.0
