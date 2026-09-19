from __future__ import annotations

from random import Random

from market_engine.config.assets import AssetConfig
from market_engine.models.price_state import PriceState


class PriceGenerator:
    def __init__(self, config: AssetConfig, rng: Random) -> None:
        self.config = config
        self.rng = rng
        self.state = PriceState(asset=config.symbol, price=config.base_price)

    def next_raw_price(self) -> float:
        state = self.state
        cfg = self.config
        if state.regime_ticks_left <= 0:
            state.regime = self.rng.choice((-1, 0, 0, 1))
            state.regime_ticks_left = self.rng.randint(24, 90)
        state.regime_ticks_left -= 1

        noise = self.rng.gauss(0.0, cfg.volatility)
        reversion = cfg.mean_reversion * (cfg.base_price - state.price) / cfg.base_price
        trend = cfg.trend_bias + (state.regime * cfg.volatility * 0.35)
        momentum = 0.42 * state.momentum
        change_pct = trend + reversion + momentum + noise
        new_price = state.price * (1.0 + change_pct)
        state.last_return = (new_price / state.price) - 1.0 if state.price else 0.0
        state.momentum = (0.65 * state.momentum) + (0.35 * state.last_return)
        return new_price
