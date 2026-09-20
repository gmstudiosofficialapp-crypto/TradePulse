from dataclasses import dataclass, field

from app.core.safety import LIVE_TRADING_ENABLED
from app.core.trading_settings import ASSET_PAYOUT_RATES, TradingSettings
from signal_engine.config.settings import SignalSettings


@dataclass(frozen=True, slots=True)
class AdminMarketControl:
    """Server-side knobs. Normal users cannot change these."""

    live_trading_enabled: bool = LIVE_TRADING_ENABLED
    trading: TradingSettings = field(default_factory=TradingSettings)
    signals: SignalSettings = field(default_factory=SignalSettings)
    assets_enabled: bool = True
    tick_interval_ms: int = 400
    volatility_note: str = "Per-asset volatility lives in market_engine.config.assets"
    trend_bias_note: str = "Per-asset trend_bias lives in market_engine.config.assets"

    def public_view(self) -> dict:
        return {
            "live_trading_enabled": False,
            "simulated": True,
            "account_type": "DEMO",
            "payout_rate": self.trading.payout_rate,
            "payout_rates": dict(ASSET_PAYOUT_RATES),
            "initial_demo_balance": self.trading.initial_balance,
            "expiry_seconds": self.trading.expiry_seconds,
            "allowed_expiry_seconds": list(self.trading.allowed_expiry_seconds),
            "min_stake": self.trading.min_stake,
            "max_stake": self.trading.max_stake,
            "max_open_trades_per_asset": self.trading.max_open_trades_per_asset,
            "max_active_signals_per_asset": self.signals.max_active_per_asset,
            "signal_version": self.signals.version,
        }
