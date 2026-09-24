from __future__ import annotations

from datetime import datetime, timezone
from threading import Lock

class MemoryAccountStore:
    def __init__(self, initial: float) -> None:
        self.initial = initial
        self.initial_live = 0.0
        self._balances: dict[str, float] = {}
        self._live_balances: dict[str, float] = {}
        self._users: dict[str, dict] = {}

    def get_balance(self, user_id: str) -> float:
        return self._balances.setdefault(user_id, self.initial)

    def set_balance(self, user_id: str, amount: float) -> None:
        self._balances[user_id] = round(amount, 2)

    def get_live_balance(self, user_id: str) -> float:
        return self._live_balances.setdefault(user_id, self.initial_live)

    def set_live_balance(self, user_id: str, amount: float) -> None:
        self._live_balances[user_id] = round(amount, 2)

    def ensure_user(self, user_id: str, email: str = "", name: str = "") -> dict:
        existing = self._users.get(user_id)
        if existing is not None:
            if email:
                existing["email"] = email
            if name:
                existing["displayName"] = name
            existing["updatedAt"] = datetime.now(timezone.utc).isoformat()
            return existing
        now = datetime.now(timezone.utc).isoformat()
        row = {
            "uid": user_id,
            "email": email,
            "displayName": name,
            "status": "active",
            "createdAt": now,
            "updatedAt": now,
        }
        self._users[user_id] = row
        self.get_balance(user_id)
        self.get_live_balance(user_id)
        return row

    def get_user(self, user_id: str) -> dict | None:
        return self._users.get(user_id)

    def save_user(self, user_id: str, fields: dict) -> dict:
        row = self.ensure_user(user_id)
        row.update(fields)
        row["uid"] = user_id
        row["updatedAt"] = datetime.now(timezone.utc).isoformat()
        self._users[user_id] = row
        return row


class MemoryTradeStore:
    def __init__(self) -> None:
        self._trades: dict[str, dict] = {}

    def save(self, trade: dict) -> None:
        self._trades[trade["trade_id"]] = dict(trade)

    def get(self, trade_id: str) -> dict | None:
        row = self._trades.get(trade_id)
        return dict(row) if row is not None else None

    def list_for_user(self, user_id: str) -> list[dict]:
        rows = [dict(t) for t in self._trades.values() if t["user_id"] == user_id]
        return sorted(rows, key=lambda item: item["created_at"], reverse=True)

    def all_open(self) -> list[dict]:
        return [dict(t) for t in self._trades.values() if t["result"] is None]

    def delete(self, trade_id: str) -> None:
        self._trades.pop(trade_id, None)


class MemoryTransactionStore:
    def __init__(self) -> None:
        self._items: dict[str, dict] = {}

    def save(self, payload: dict) -> None:
        self._items[payload["transaction_id"]] = dict(payload)

    def list_for_user(self, user_id: str) -> list[dict]:
        rows = [dict(item) for item in self._items.values() if item["user_id"] == user_id]
        return sorted(rows, key=lambda item: item["createdAt"], reverse=True)


class MemorySignalStore:
    def __init__(self) -> None:
        self._items: list[dict] = []

    def save(self, payload: dict) -> None:
        self._items.append(payload)

    def list_for_asset(self, asset: str) -> list[dict]:
        return [item for item in self._items if item["asset"] == asset]


class MemoryLedger:
    """Process-local lock around the existing memory stores."""

    def __init__(
        self,
        accounts: MemoryAccountStore,
        trades: MemoryTradeStore,
        transactions: MemoryTransactionStore | None = None,
    ) -> None:
        self.accounts = accounts
        self.trades = trades
        self.transactions = transactions or MemoryTransactionStore()
        self._lock = Lock()

    def commit_open(
        self,
        *,
        user_id: str,
        stake: float,
        asset: str,
        max_open: int,
        trade: dict,
        transaction: dict,
    ) -> dict:
        with self._lock:
            book = trade.get("account_type") or "DEMO"
            if book == "LIVE":
                available = self.accounts.get_live_balance(user_id)
                if stake > available:
                    raise ValueError("Insufficient live balance")
            else:
                available = self.accounts.get_balance(user_id)
                if stake > available:
                    raise ValueError("Insufficient demo balance")
            open_trades = [
                item
                for item in self.trades.list_for_user(user_id)
                if item.get("result") is None
                and (item.get("account_type") or "DEMO") == book
            ]
            if len(open_trades) >= max_open:
                raise ValueError("Maximum 10 active trades reached.")
            before = available
            after = round(available - stake, 2)
            if book == "LIVE":
                self.accounts.set_live_balance(user_id, after)
            else:
                self.accounts.set_balance(user_id, after)
            transaction["balanceBefore"] = before
            transaction["balanceAfter"] = after
            self.trades.save(trade)
            self.transactions.save(transaction)
            return dict(trade)

    def commit_credit(self, user_id: str, amount: float) -> float:
        with self._lock:
            if amount <= 0:
                raise ValueError("Invalid credit amount")
            before = self.accounts.get_balance(user_id)
            after = round(before + amount, 2)
            self.accounts.set_balance(user_id, after)
            self.transactions.save(
                {
                    "transaction_id": f"demo-credit-{user_id}-{datetime.now(timezone.utc).isoformat()}",
                    "user_id": user_id,
                    "type": "DEMO_CREDIT",
                    "amount": round(amount, 2),
                    "balanceBefore": before,
                    "balanceAfter": after,
                    "simulated": True,
                    "createdAt": datetime.now(timezone.utc).isoformat(),
                }
            )
            return after

    def commit_settle(
        self,
        trade_id: str,
        expiry_price: float,
        apply,
    ) -> dict:
        with self._lock:
            trade = self.trades.get(trade_id)
            if trade is None:
                raise ValueError("Trade not found")
            updated, credit, txn = apply(trade, expiry_price)
            book = updated.get("account_type") or "DEMO"
            if txn is not None:
                user_id = updated["user_id"]
                if book == "LIVE":
                    before = self.accounts.get_live_balance(user_id)
                    after = round(before + credit, 2)
                    self.accounts.set_live_balance(user_id, after)
                else:
                    before = self.accounts.get_balance(user_id)
                    after = round(before + credit, 2)
                    self.accounts.set_balance(user_id, after)
                txn["balanceBefore"] = before
                txn["balanceAfter"] = after
                txn["account_type"] = book
                self.transactions.save(txn)
            elif credit:
                user_id = updated["user_id"]
                if book == "LIVE":
                    self.accounts.set_live_balance(
                        user_id,
                        round(self.accounts.get_live_balance(user_id) + credit, 2),
                    )
                else:
                    self.accounts.set_balance(
                        user_id,
                        round(self.accounts.get_balance(user_id) + credit, 2),
                    )
            self.trades.save(updated)
            return dict(updated)
