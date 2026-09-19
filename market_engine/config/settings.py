from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class EngineSettings:
    history_size: int = 500
    warmup_ticks_per_minute: int = 8
    default_tick_interval_ms: int = 400
    seed: int = 20260918
