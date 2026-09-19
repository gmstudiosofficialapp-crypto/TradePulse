from __future__ import annotations

from datetime import datetime, timezone
from random import Random

from market_engine.config.assets import AssetConfig
from market_engine.generators.price_generator import PriceGenerator
from market_engine.models.tick import Tick
from market_engine.services.price_validator import validate_price


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class TickEngine:
    def __init__(self, config: AssetConfig, rng: Random) -> None:
        self.config = config
        self.generator = PriceGenerator(config, rng)

    @property
    def price(self) -> float:
        return self.generator.state.price

    def next_tick(self, timestamp: datetime | None = None) -> Tick:
        raw = self.generator.next_raw_price()
        previous = self.generator.state.price
        price = validate_price(previous, raw, self.config)
        self.generator.state.price = price
        ts = timestamp or utc_now()
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=timezone.utc)
        else:
            ts = ts.astimezone(timezone.utc)
        return Tick(asset=self.config.symbol, timestamp=ts, price=price)
