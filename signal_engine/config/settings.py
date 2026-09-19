from dataclasses import dataclass

MAX_ACTIVE_SIGNALS_PER_ASSET = 10


@dataclass(frozen=True, slots=True)
class SignalSettings:
    min_confidence: float = 0.72
    min_body_ratio: float = 0.35
    min_trend: float = 0.0004
    choppiness_limit: float = 0.55
    expiry_seconds: int = 60
    version: str = "momentum-v1"
    max_active_per_asset: int = MAX_ACTIVE_SIGNALS_PER_ASSET
