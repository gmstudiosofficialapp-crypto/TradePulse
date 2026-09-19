from __future__ import annotations

import copy
from random import Random

from market_engine.generators.price_generator import PriceGenerator
from market_engine.services.market_runtime import AssetStream
from market_engine.services.price_validator import validate_price


def peek_reference_direction(stream: AssetStream, steps: int = 8) -> dict:
    """Private ground-truth peek. Must never feed the public signal engine."""
    live_rng: Random = stream.ticks.generator.rng
    saved = live_rng.getstate()
    tmp = PriceGenerator(stream.config, live_rng)
    tmp.state = copy.deepcopy(stream.ticks.generator.state)
    prices = [tmp.state.price]
    for _ in range(steps):
        raw = tmp.next_raw_price()
        price = validate_price(prices[-1], raw, stream.config)
        tmp.state.price = price
        prices.append(price)
    live_rng.setstate(saved)
    start, end = prices[0], prices[-1]
    if end > start:
        direction = "BUY"
        move = "UP"
    elif end < start:
        direction = "SELL"
        move = "DOWN"
    else:
        direction = "NO_SIGNAL"
        move = "FLAT"
    return {
        "asset": stream.config.symbol,
        "reference_direction": direction,
        "next_candle_result": move,
        "reference_entry": start,
        "reference_exit": end,
        "label": "PRIVATE TEST / GROUND TRUTH",
        "not_a_prediction": True,
        "simulated": True,
    }
