from __future__ import annotations

from datetime import datetime, timezone
from threading import Lock

SIGNUP_LIVE_BONUS = 0.0
INITIAL_LIVE_BALANCE = 0.0


class MemoryAccountStore:
    def __init__(self, initial: float) -> None:
        self.initial = initial
        self.initial_live = 0.0
        self._balances: dict[str, float] = {}
        self._live_balances: dict[str, float] = {}
        self._bonus_granted: dict[str, bool] = {}
        self._users: dict[str, dict] = {}
        self._lock = Lock()

    def get_balance(self, user_id: str) -> float:
        return self._balances.setdefault(user_id, self.initial)

    def set_balance(self, user_id: str, amount: float) -> None:
        self._balances[user_id] = round(amount, 2)

    def get_live_balance(self, user_id: str) -> float:
        return self._live_balances.setdefault(user_id, self.initial_live)

    def set_live_balance(self, user_id: str, amount: float) -> None:
        self._live_balances[user_id] = round(amount, 2)

    def ensure_user(self, user_id: str, email: str = "", name: str = "") -> dict:
        with self._lock:
            existing = self._users.get(user_id)
            account_exists = user_id in self._balances or user_id in self._live_balances
            now = datetime.now(timezone.utc).isoformat()
            if existing is not None or account_exists:
                if existing is None:
                    existing = {
                        "uid": user_id,
                        "email": email,
                        "displayName": name,
                        "status": "active",
                        "createdAt": now,
                        "updatedAt": now,
                    }
                    self._users[user_id] = existing
                else:
                    if email:
                        existing["email"] = email
                    if name and not str(existing.get("displayName") or "").strip():
                        existing["displayName"] = name
                    existing["updatedAt"] = now
                granted = bool(self._bonus_granted.get(user_id))
                return {
                    **existing,
                    "signup_bonus_granted": granted,
                    "signup_bonus_just_granted": False,
                }
            row = {
                "uid": user_id,
                "email": email,
                "displayName": name,
                "status": "active",
                "createdAt": now,
                "updatedAt": now,
            }
            self._users[user_id] = row
            self._balances[user_id] = round(self.initial, 2)
            self._live_balances[user_id] = INITIAL_LIVE_BALANCE
            self._bonus_granted[user_id] = False
            return {
                **row,
                "signup_bonus_granted": False,
                "signup_bonus_just_granted": False,
            }

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


class MemoryWithdrawalStore:
    def __init__(self, accounts: MemoryAccountStore | None = None) -> None:
        self.accounts = accounts
        self._items: dict[str, dict] = {}
        self._lock = Lock()

    def bind_accounts(self, accounts: MemoryAccountStore) -> None:
        self.accounts = accounts

    def get(self, request_id: str) -> dict | None:
        row = self._items.get(request_id)
        return dict(row) if row is not None else None

    def list_for_user(self, user_id: str) -> list[dict]:
        rows = [dict(item) for item in self._items.values() if item.get("user_id") == user_id]
        return sorted(rows, key=lambda item: item.get("created_at", ""), reverse=True)

    def list_all(self) -> list[dict]:
        rows = [dict(item) for item in self._items.values()]
        return sorted(rows, key=lambda item: item.get("created_at", ""), reverse=True)

    def create_pending(self, row: dict) -> tuple[dict, float]:
        from app.services.withdraw import (
            MSG_INSUFFICIENT,
            MSG_PENDING,
            STATUS_PENDING,
            WithdrawError,
        )

        if self.accounts is None:
            raise RuntimeError("Withdrawal account store is unavailable")
        with self._lock:
            user_id = row["user_id"]
            if any(
                item.get("user_id") == user_id and item.get("status") == STATUS_PENDING
                for item in self._items.values()
            ):
                raise WithdrawError(MSG_PENDING, "pending")
            available = self.accounts.get_live_balance(user_id)
            amount = float(row["amount_usd"])
            if amount > available:
                raise WithdrawError(MSG_INSUFFICIENT)
            after = round(available - amount, 2)
            if after < 0:
                raise WithdrawError(MSG_INSUFFICIENT)
            self.accounts.set_live_balance(user_id, after)
            stored = dict(row)
            stored["refunded"] = False
            self._items[stored["request_id"]] = stored
            return dict(stored), after

    def approve(self, request_id: str, admin_username: str) -> dict:
        from app.services.withdraw import (
            MSG_ALREADY_REJECTED,
            MSG_NOT_FOUND,
            STATUS_PENDING,
            STATUS_REJECTED,
            STATUS_SUCCESSFUL,
            WithdrawError,
        )

        with self._lock:
            row = self._items.get(request_id)
            if row is None:
                raise WithdrawError(MSG_NOT_FOUND, "not_found")
            if row["status"] == STATUS_SUCCESSFUL:
                return dict(row)
            if row["status"] == STATUS_REJECTED:
                raise WithdrawError(MSG_ALREADY_REJECTED, "conflict")
            if row["status"] != STATUS_PENDING:
                raise WithdrawError(MSG_ALREADY_REJECTED, "conflict")
            now = datetime.now(timezone.utc).isoformat()
            row["status"] = STATUS_SUCCESSFUL
            row["updated_at"] = now
            row["processed_at"] = now
            row["processed_by"] = admin_username
            return dict(row)

    def reject(self, request_id: str, admin_username: str, reason: str) -> tuple[dict, float]:
        from app.services.withdraw import (
            MSG_ALREADY_SUCCESSFUL,
            MSG_NOT_FOUND,
            STATUS_PENDING,
            STATUS_REJECTED,
            STATUS_SUCCESSFUL,
            WithdrawError,
        )

        if self.accounts is None:
            raise RuntimeError("Withdrawal account store is unavailable")
        with self._lock:
            row = self._items.get(request_id)
            if row is None:
                raise WithdrawError(MSG_NOT_FOUND, "not_found")
            user_id = row["user_id"]
            live = self.accounts.get_live_balance(user_id)
            if row["status"] == STATUS_REJECTED:
                return dict(row), live
            if row["status"] == STATUS_SUCCESSFUL:
                raise WithdrawError(MSG_ALREADY_SUCCESSFUL, "conflict")
            if row["status"] != STATUS_PENDING:
                raise WithdrawError(MSG_ALREADY_SUCCESSFUL, "conflict")
            amount = float(row["amount_usd"])
            if not row.get("refunded"):
                live = round(live + amount, 2)
                self.accounts.set_live_balance(user_id, live)
                row["refunded"] = True
            now = datetime.now(timezone.utc).isoformat()
            row["status"] = STATUS_REJECTED
            row["rejection_reason"] = reason
            row["updated_at"] = now
            row["processed_at"] = now
            row["processed_by"] = admin_username
            return dict(row), live


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
