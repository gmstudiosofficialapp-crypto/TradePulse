from __future__ import annotations

import threading
import uuid
from datetime import datetime, timedelta, timezone

from app.core.trading_settings import TradingSettings, payout_rate_for
from app.persistence.memory import (
    MemoryAccountStore,
    MemoryLedger,
    MemoryTradeStore,
    MemoryTransactionStore,
)


HISTORY_LIMIT = 100
BOOK_DEMO = "DEMO"
BOOK_LIVE = "LIVE"


def account_book(trade: dict) -> str:
    return BOOK_LIVE if trade.get("account_type") == BOOK_LIVE else BOOK_DEMO


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
        self._hot_open: dict[str, dict] = {}
        self._hot_ready = False
        self._overlay: dict[str, dict] = {}
        self._balance_cache: dict[str, float] = {}
        self._live_balance_cache: dict[str, float] = {}
        self._persist_lock = threading.Lock()

    def balance(self, user_id: str) -> float:
        cached = self._balance_cache.get(user_id)
        if cached is not None:
            return cached
        return self.accounts.get_balance(user_id)

    def live_balance(self, user_id: str) -> float:
        cached = self._live_balance_cache.get(user_id)
        if cached is not None:
            return cached
        getter = getattr(self.accounts, "get_live_balance", None)
        if getter is None:
            return 0.0
        return getter(user_id)

    def set_live_balance(self, user_id: str, amount: float) -> float:
        after = round(amount, 2)
        setter = getattr(self.accounts, "set_live_balance", None)
        if setter is None:
            raise ValueError("Live balance store is unavailable")
        setter(user_id, after)
        self._live_balance_cache[user_id] = after
        return after

    def book_balance(self, user_id: str, book: str) -> float:
        if book == BOOK_LIVE:
            return self.live_balance(user_id)
        return self.balance(user_id)

    def open_snapshot(self) -> list[dict]:
        """Open trades kept in memory so expiry does not query Firestore per tick."""
        self._ensure_hot()
        return [dict(trade) for trade in self._hot_open.values()]

    def listed_trades(self, user_id: str, account_type: str = BOOK_DEMO) -> list[dict]:
        rows = {item["trade_id"]: item for item in self.trades.list_for_user(user_id)}
        for trade_id, trade in self._overlay.items():
            if trade.get("user_id") == user_id:
                rows[trade_id] = trade
        rows = {
            key: value
            for key, value in rows.items()
            if account_book(value) == account_type
        }
        ordered = sorted(
            rows.values(),
            key=lambda item: (item.get("created_at", ""), item.get("trade_id", "")),
            reverse=True,
        )
        return ordered[:HISTORY_LIMIT]

    def _ensure_hot(self) -> None:
        if self._hot_ready:
            return
        for trade in self.trades.all_open():
            trade_id = trade.get("trade_id")
            if trade_id:
                self._hot_open.setdefault(trade_id, dict(trade))
        self._hot_ready = True

    def _trim_history(self, user_id: str, account_type: str = BOOK_DEMO) -> None:
        rows = [
            row
            for row in self.trades.list_for_user(user_id)
            if account_book(row) == account_type
        ]
        extra = len(rows) - HISTORY_LIMIT
        if extra <= 0:
            return
        closed_oldest = [row for row in reversed(rows) if row.get("result") is not None]
        for row in closed_oldest[:extra]:
            trade_id = row.get("trade_id")
            if not trade_id:
                continue
            self.trades.delete(trade_id)
            self._overlay.pop(trade_id, None)

    def credit_demo(self, user_id: str, amount: float) -> float:
        if amount <= 0:
            raise ValueError("Invalid credit amount")
        credited = round(amount, 2)
        if hasattr(self.ledger, "commit_credit"):
            after = self.ledger.commit_credit(user_id, credited)
        else:
            after = round(self.balance(user_id) + credited, 2)
            self.accounts.set_balance(user_id, after)
        if user_id in self._balance_cache:
            self._balance_cache[user_id] = after
        return after

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
        book = BOOK_LIVE if live else BOOK_DEMO
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
            "payout_rate": payout_rate_for(asset, self.settings.payout_rate),
            "result": None,
            "profit_loss": 0.0,
            "status": "OPEN",
            "created_at": moment.isoformat(),
            "simulated": True,
            "account_type": book,
        }
        entry_txn = {
            "transaction_id": str(uuid.uuid4()),
            "user_id": user_id,
            "type": "TRADE_ENTRY",
            "amount": -round(stake, 2),
            "referenceId": trade_id,
            "createdAt": moment.isoformat(),
            "account_type": book,
        }
        opened = self.ledger.commit_open(
            user_id=user_id,
            stake=round(stake, 2),
            asset=asset,
            max_open=self.settings.max_open_trades_per_asset,
            trade=trade,
            transaction=entry_txn,
        )
        self._hot_open[opened["trade_id"]] = dict(opened)
        self._hot_ready = True
        if getattr(self.ledger, "defer_writes", False):
            self._overlay[opened["trade_id"]] = dict(opened)
        if book == BOOK_LIVE:
            getter = getattr(self.accounts, "get_live_balance", None)
            if getter is not None:
                self._live_balance_cache[user_id] = getter(user_id)
        elif user_id in self._balance_cache:
            self._balance_cache[user_id] = self.accounts.get_balance(user_id)
        self._trim_history(user_id, book)
        return opened

    def settle(self, trade_id: str, expiry_price: float) -> dict:
        if getattr(self.ledger, "defer_writes", False):
            return self._settle_hot(trade_id, expiry_price)
        updated = self.ledger.commit_settle(trade_id, expiry_price, _compute_settlement)
        self._hot_open.pop(trade_id, None)
        book = account_book(updated)
        user_id = updated["user_id"]
        if book == BOOK_LIVE:
            getter = getattr(self.accounts, "get_live_balance", None)
            if getter is not None:
                self._live_balance_cache[user_id] = getter(user_id)
        elif user_id in self._balance_cache:
            self._balance_cache[user_id] = self.accounts.get_balance(user_id)
        self._trim_history(user_id, book)
        return updated

    def _settle_hot(self, trade_id: str, expiry_price: float) -> dict:
        self._ensure_hot()
        trade = self._hot_open.get(trade_id) or self._overlay.get(trade_id)
        if trade is None:
            stored = self.trades.get(trade_id)
            if stored is None:
                raise ValueError("Trade not found")
            trade = stored
        if trade.get("result") is not None:
            return dict(trade)
        updated, credit, _extra = _compute_settlement(trade, expiry_price)
        user_id = updated["user_id"]
        book = account_book(updated)
        if credit:
            if book == BOOK_LIVE:
                self._live_balance_cache[user_id] = round(
                    self._cached_live_balance(user_id) + credit, 2
                )
            else:
                self._balance_cache[user_id] = round(self._cached_balance(user_id) + credit, 2)
        elif book == BOOK_LIVE:
            self._cached_live_balance(user_id)
        elif user_id not in self._balance_cache:
            self._cached_balance(user_id)
        self._overlay[trade_id] = updated
        self._hot_open.pop(trade_id, None)
        threading.Thread(
            target=self._persist_settle,
            args=(trade_id, expiry_price, user_id),
            daemon=True,
        ).start()
        return updated

    def _cached_balance(self, user_id: str) -> float:
        if user_id not in self._balance_cache:
            self._balance_cache[user_id] = self.accounts.get_balance(user_id)
        return self._balance_cache[user_id]

    def _cached_live_balance(self, user_id: str) -> float:
        if user_id not in self._live_balance_cache:
            self._live_balance_cache[user_id] = self.live_balance(user_id)
        return self._live_balance_cache[user_id]

    def _persist_settle(self, trade_id: str, expiry_price: float, user_id: str) -> None:
        with self._persist_lock:
            try:
                updated = self.ledger.commit_settle(trade_id, expiry_price, _compute_settlement)
                self._trim_history(user_id, account_book(updated))
            except Exception:
                return

    def statistics(self, user_id: str, account_type: str = BOOK_DEMO) -> dict:
        rows = [t for t in self.listed_trades(user_id, account_type) if t.get("result")]
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
            "current_balance": self.book_balance(user_id, account_type),
            "best_streak": best,
            "current_streak": streak,
            "simulated": True,
        }
