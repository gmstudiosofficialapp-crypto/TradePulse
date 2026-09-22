from __future__ import annotations

from collections.abc import Awaitable, Callable
from datetime import datetime, timezone

from app.services.demo_trading import DemoTradingEngine
from app.services.ground_truth import peek_reference_direction
from market_engine.models.candle import Candle
from market_engine.models.tick import Tick
from market_engine.services.market_runtime import MarketRuntime
from signal_engine.services.engine import SignalEngine

EventHandler = Callable[[dict], Awaitable[None] | None]


class Phase3Coordinator:
    def __init__(
        self,
        market: MarketRuntime,
        signals: SignalEngine,
        trading: DemoTradingEngine,
    ) -> None:
        self.market = market
        self.signals = signals
        self.trading = trading
        self.latest_signals: dict[str, dict] = {}
        self.latest_truth: dict[str, dict] = {}
        self._events: list[EventHandler] = []
        self._live = False

    def add_event_handler(self, handler: EventHandler) -> None:
        if handler not in self._events:
            self._events.append(handler)

    def enable_live(self) -> None:
        self._live = True

    def banner_for(self, asset: str) -> dict:
        latest = self.signals.latest_for(asset)
        if latest is not None:
            return latest.to_dict()
        return self.latest_signals.get(asset) or {
            "asset": asset,
            "direction": "NO_SIGNAL",
            "status": "WAITING",
            "confidence": 0,
            "timeframe": "1m",
        }

    async def on_market(
        self,
        tick: Tick,
        candle: Candle,
        closed: Candle | None,
    ) -> None:
        if closed is None or not self._live:
            await self._settle_due(tick.timestamp)
            return
        history = [
            item
            for item in self.market.store.history(closed.asset)
            if item.closed
        ]
        before = {item.signal_id for item in self.signals.directional_for(closed.asset)}
        signal = self.signals.analyze_closed(closed.asset, history, now=closed.close_time)
        if signal.direction in {"BUY", "SELL"} and signal.signal_id not in before:
            payload = signal.to_dict()
            self.latest_signals[closed.asset] = self.banner_for(closed.asset)
            await self._emit({"type": "signal_created", "asset": closed.asset, "signal": payload})
        else:
            self.latest_signals[closed.asset] = self.banner_for(closed.asset)
        stream = self.market.streams[closed.asset]
        truth = peek_reference_direction(stream)
        truth["closed_candle"] = closed.to_dict()
        self.latest_truth[closed.asset] = truth
        await self._emit({"type": "ground_truth", **truth})
        await self._settle_due(tick.timestamp, preferred={closed.asset: closed.close})

    async def _settle_due(
        self,
        now: datetime,
        preferred: dict[str, float] | None = None,
    ) -> None:
        moment = now if now.tzinfo else now.replace(tzinfo=timezone.utc)
        preferred = preferred or {}
        for trade in list(self.trading.open_snapshot()):
            expiry = datetime.fromisoformat(trade["expiry_time"])
            if expiry.tzinfo is None:
                expiry = expiry.replace(tzinfo=timezone.utc)
            if expiry > moment:
                continue
            price = preferred.get(trade["asset"])
            if price is None:
                quote = self.market.quotes.get(trade["asset"])
                price = quote.price if quote else trade["entry_price"]
            settled = self.trading.settle(trade["trade_id"], price)
            await self._emit({"type": "trade_result", "trade": settled})
            await self._emit(
                {
                    "type": "balance_updated",
                    "user_id": settled["user_id"],
                    "balance": self.trading.balance(settled["user_id"]),
                }
            )
        for signal in list(self.signals.all_signals()):
            if signal.direction == "NO_SIGNAL" or signal.result is not None:
                continue
            if signal.expiry_time <= moment:
                quote = self.market.quotes.get(signal.asset)
                price = preferred.get(signal.asset) or (quote.price if quote else signal.entry_price)
                settled = self.signals.settle(signal.signal_id, price, now=moment)
                self.latest_signals[signal.asset] = self.banner_for(signal.asset)
                await self._emit(
                    {"type": "signal_closed", "asset": signal.asset, "signal": settled.to_dict()}
                )

    async def _emit(self, payload: dict) -> None:
        for handler in self._events:
            result = handler(payload)
            if hasattr(result, "__await__"):
                await result
