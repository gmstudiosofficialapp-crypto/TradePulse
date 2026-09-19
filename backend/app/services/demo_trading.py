from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

from app.core.safety import execute_live_trade
from app.core.trading_settings import TradingSettings
from app.persistence.memory import (
    MemoryAccountStore,
    MemoryLedger,
    MemoryTradeStore,
    MemoryTransactionStore,
)


def _utc(now: datetime | None) -> datetime:
    moment = now or datetime.now(timezone.utc)
    if moment.tzinfo is None:
        return moment.replace(tzinfo=timezone.utc)
    return moment.astimezone(timezone.utc)


def _compute_settlement(trade: dict, expiry_price: float) -> tuple[dict, float, dict | None]:
    if trade.get("result") is not None:
        return dict(trade), 0.0, None
    entry = trade["entry_price"]
    direction = trade["direction"]
    stake = trade["stake"]
    rate = trade["payout_rate"]
    if direction == "BUY":
        result = "WIN" if expiry_price > entry else "LOSS" if expiry_price < entry else "DRAW"
    else:
        result = "WIN" if expiry_price < entry else "LOSS" if expiry_price > entry else "DRAW"
    credit = 0.0
    txn_type = None
    if result == "WIN":
        profit = round(stake * rate, 2)
        credit = stake + profit
        pnl = profit
        txn_type = "TRADE_PAYOUT"
    elif result == "DRAW":
        credit = stake
        pnl = 0.0
        txn_type = "TRADE_REFUND"
    else:
        pnl = -stake
    updated = dict(trade)
    updated["expiry_price"] = expiry_price
    updated["result"] = result
    updated["profit_loss"] = pnl
    updated["status"] = "CLOSED"
    extra = None
    if txn_type is not None:
        extra = {
            "transaction_id": str(uuid.uuid4()),
            "user_id": trade["user_id"],
            "type": txn_type,
            "amount": credit,
            "referenceId": trade["trade_id"],
            "createdAt": datetime.now(timezone.utc).isoformat(),
        }
    return updated, credit, extra


class DemoTradingEngine:
    def __init__(
        self,
        settings: TradingSettings | None = None,
        accounts: MemoryAccountStore | None = None,
        trades: MemoryTradeStore | None = None,
        transactions: MemoryTransactionStore | None = None,
        ledger=None,
    ) -> None:
        self.settings = settings or TradingSettings()
        self.accounts = accounts or MemoryAccountStore(self.settings.initial_balance)
        self.trades = trades or MemoryTradeStore()
        self.transactions = transactions or MemoryTransactionStore()
        self.ledger = ledger or MemoryLedger(self.accounts, self.trades, self.transactions)

    def balance(self, user_id: str) -> float:
        return self.accounts.get_balance(user_id)

    def ensure_account(self, user_id: str, email: str = "", name: str = "") -> dict:
        if hasattr(self.accounts, "ensure_user"):
            return self.accounts.ensure_user(user_id, email=email, name=name)
        return {"uid": user_id, "email": email, "displayName": name}

    def update_profile(self, user_id: str, fields: dict) -> dict:
        if hasattr(self.accounts, "save_user"):
            return self.accounts.save_user(user_id, fields)
        return {"uid": user_id, **fields}

    def profile(self, user_id: str) -> dict | None:
        if hasattr(self.accounts, "get_user"):
            return self.accounts.get_user(user_id)
        return None

    def open_trade(
        self,
        user_id: str,
        asset: str,
        direction: str,
        stake: float,
        entry_price: float,
        now: datetime | None = None,
        live: bool = False,
        expiry_seconds: int | None = None,
    ) -> dict:
        if live:
            execute_live_trade()
        if direction not in {"BUY", "SELL"}:
            raise ValueError("Direction must be BUY or SELL")
        if entry_price <= 0:
            raise ValueError("Invalid entry price")
        duration = expiry_seconds if expiry_seconds is not None else self.settings.expiry_seconds
        if duration not in self.settings.allowed_expiry_seconds:
            raise ValueError("Invalid expiry")
        moment = _utc(now)
        if stake < self.settings.min_stake or stake > self.settings.max_stake:
            raise ValueError("Invalid stake")
        trade_id = str(uuid.uuid4())
        trade = {
            "trade_id": trade_id,
            "user_id": user_id,
            "asset": asset,
            "direction": direction,
            "stake": round(stake, 2),
            "entry_price": entry_price,
            "entry_time": moment.isoformat(),
            "expiry_time": (moment + timedelta(seconds=duration)).isoformat(),
            "expiry_seconds": duration,
            "expiry_price": None,
            "payout_rate": self.settings.payout_rate,
            "result": None,
            "profit_loss": 0.0,
            "status": "OPEN",
            "created_at": moment.isoformat(),
            "simulated": True,
        }
        entry_txn = {
            "transaction_id": str(uuid.uuid4()),
            "user_id": user_id,
            "type": "TRADE_ENTRY",
            "amount": -round(stake, 2),
            "referenceId": trade_id,
            "createdAt": moment.isoformat(),
        }
        return self.ledger.commit_open(
            user_id=user_id,
            stake=round(stake, 2),
            asset=asset,
            max_open=self.settings.max_open_trades_per_asset,
            trade=trade,
            transaction=entry_txn,
        )

    def settle(self, trade_id: str, expiry_price: float) -> dict:
        return self.ledger.commit_settle(trade_id, expiry_price, _compute_settlement)

    def statistics(self, user_id: str) -> dict:
        rows = [t for t in self.trades.list_for_user(user_id) if t["result"]]
        wins = sum(1 for t in rows if t["result"] == "WIN")
        losses = sum(1 for t in rows if t["result"] == "LOSS")
        draws = sum(1 for t in rows if t["result"] == "DRAW")
        total = len(rows)
        pnl = round(sum(t["profit_loss"] for t in rows), 2)
        best = 0
        current = 0
        for trade in reversed(rows):
            if trade["result"] == "WIN":
                current += 1
                best = max(best, current)
            else:
                current = 0
        streak = 0
        for trade in rows:
            if trade["result"] == "WIN":
                streak += 1
            else:
                break
        return {
            "total_trades": total,
            "wins": wins,
            "losses": losses,
            "draws": draws,
            "win_rate": round((wins / total) * 100, 2) if total else 0.0,
            "total_profit_loss": pnl,
            "current_balance": self.balance(user_id),
            "best_streak": best,
            "current_streak": streak,
            "simulated": True,
        }
