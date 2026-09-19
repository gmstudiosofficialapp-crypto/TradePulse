from __future__ import annotations

import math

from market_engine.config.assets import AssetConfig


def quantize(price: float, precision: int) -> float:
    factor = 10**precision
    return math.floor(price * factor + 0.5) / factor


def validate_price(previous: float, candidate: float, config: AssetConfig) -> float:
    if not math.isfinite(candidate) or candidate <= 0:
        return previous
    max_delta = max(previous * config.max_move_pct, config.min_tick)
    delta = candidate - previous
    if abs(delta) > max_delta:
        candidate = previous + math.copysign(max_delta, delta)
    if abs(candidate - previous) < config.min_tick and candidate != previous:
        candidate = previous + math.copysign(config.min_tick, candidate - previous or 1)
    quantized = quantize(candidate, config.precision)
    if quantized <= 0:
        return previous
    if abs(quantized - previous) > max_delta:
        quantized = quantize(
            previous + math.copysign(max_delta, quantized - previous),
            config.precision,
        )
    return quantized
