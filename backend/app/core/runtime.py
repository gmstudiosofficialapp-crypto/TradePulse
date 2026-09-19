from app.core.admin_config import AdminMarketControl
from app.services.coordinator import Phase3Coordinator
from app.services.demo_trading import DemoTradingEngine
from market_engine.services.market_runtime import MarketRuntime
from signal_engine.services.engine import SignalEngine

_runtime: MarketRuntime | None = None
_signals: SignalEngine | None = None
_trading: DemoTradingEngine | None = None
_coordinator: Phase3Coordinator | None = None
_admin: AdminMarketControl | None = None


def set_runtime(runtime: MarketRuntime) -> None:
    global _runtime
    _runtime = runtime


def get_runtime() -> MarketRuntime:
    if _runtime is None:
        raise RuntimeError("Market runtime is not initialized")
    return _runtime


def set_phase3(
    signals: SignalEngine,
    trading: DemoTradingEngine,
    coordinator: Phase3Coordinator,
    admin: AdminMarketControl,
) -> None:
    global _signals, _trading, _coordinator, _admin
    _signals = signals
    _trading = trading
    _coordinator = coordinator
    _admin = admin


def get_signals() -> SignalEngine:
    if _signals is None:
        raise RuntimeError("Signal engine is not initialized")
    return _signals


def get_trading() -> DemoTradingEngine:
    if _trading is None:
        raise RuntimeError("Demo trading engine is not initialized")
    return _trading


def get_coordinator() -> Phase3Coordinator:
    if _coordinator is None:
        raise RuntimeError("Phase 3 coordinator is not initialized")
    return _coordinator


def get_admin() -> AdminMarketControl:
    if _admin is None:
        raise RuntimeError("Admin config is not initialized")
    return _admin
