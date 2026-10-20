from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from firebase_admin import firestore

from app.core.firebase_admin_app import firestore_client

def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


SIGNUP_LIVE_BONUS = 0.0
INITIAL_LIVE_BALANCE = 0.0


class FirestoreAccountStore:
    def __init__(self, db, initial: float) -> None:
        self._db = db
        self.initial = initial

    def _account_ref(self, user_id: str):
        return self._db.collection("accounts").document(user_id)

    def _user_ref(self, user_id: str):
        return self._db.collection("users").document(user_id)

    def get_balance(self, user_id: str) -> float:
        snap = self._account_ref(user_id).get()
        if not snap.exists:
            return self.initial
        data = snap.to_dict() or {}
        return float(data.get("balance", self.initial))

    def set_balance(self, user_id: str, amount: float) -> None:
        self._account_ref(user_id).set(
            {
                "uid": user_id,
                "balance": round(amount, 2),
                "updatedAt": _now(),
            },
            merge=True,
        )

    def get_live_balance(self, user_id: str) -> float:
        snap = self._account_ref(user_id).get()
        if not snap.exists:
            return 0.0
        data = snap.to_dict() or {}
        return float(data.get("live_balance", 0.0))

    def set_live_balance(self, user_id: str, amount: float) -> None:
        self._account_ref(user_id).set(
            {
                "uid": user_id,
                "live_balance": round(amount, 2),
                "updatedAt": _now(),
            },
            merge=True,
        )

    def ensure_user(self, user_id: str, email: str = "", name: str = "") -> dict:
        user_ref = self._user_ref(user_id)
        account_ref = self._account_ref(user_id)
        user_snap = user_ref.get()
        now = _now()
        if user_snap.exists:
            row = user_snap.to_dict() or {}
            updates: dict[str, Any] = {"updatedAt": now}
            if email:
                updates["email"] = email
            if name and not str(row.get("displayName") or "").strip():
                updates["displayName"] = name
            user_ref.set(updates, merge=True)
            row.update(updates)
        else:
            row = {
                "uid": user_id,
                "email": email,
                "displayName": name,
                "status": "active",
                "createdAt": now,
                "updatedAt": now,
            }
            user_ref.set(row)

        @firestore.transactional
        def _ensure_account(txn) -> dict:
            snap = account_ref.get(transaction=txn)
            if snap.exists:
                data = snap.to_dict() or {}
                return {
                    "signup_bonus_granted": bool(data.get("signup_bonus_granted")),
                    "signup_bonus_just_granted": False,
                }
            payload = {
                "uid": user_id,
                "balance": self.initial,
                "live_balance": INITIAL_LIVE_BALANCE,
                "signup_bonus_granted": False,
                "createdAt": now,
                "updatedAt": now,
            }
            txn.set(account_ref, payload)
            return {
                "signup_bonus_granted": False,
                "signup_bonus_just_granted": False,
            }

        bonus = _ensure_account(self._db.transaction())
        return {**row, **bonus}

    def get_user(self, user_id: str) -> dict | None:
        snap = self._user_ref(user_id).get()
        if not snap.exists:
            return None
        return snap.to_dict()

    def save_user(self, user_id: str, fields: dict) -> dict:
        payload = {**fields, "uid": user_id, "updatedAt": _now()}
        self._user_ref(user_id).set(payload, merge=True)
        return self.get_user(user_id) or payload


class FirestoreTradeStore:
    def __init__(self, db) -> None:
        self._db = db

    def save(self, trade: dict) -> None:
        self._db.collection("trades").document(trade["trade_id"]).set(dict(trade))

    def get(self, trade_id: str) -> dict | None:
        snap = self._db.collection("trades").document(trade_id).get()
        if not snap.exists:
            return None
        return snap.to_dict()

    def list_for_user(self, user_id: str) -> list[dict]:
        rows = [
            doc.to_dict() or {}
            for doc in self._db.collection("trades").where("user_id", "==", user_id).stream()
        ]
        return sorted(rows, key=lambda item: item.get("created_at", ""), reverse=True)

    def all_open(self) -> list[dict]:
        return [
            doc.to_dict() or {}
            for doc in self._db.collection("trades").where("status", "==", "OPEN").stream()
        ]

    def delete(self, trade_id: str) -> None:
        self._db.collection("trades").document(trade_id).delete()


class FirestoreTransactionStore:
    def __init__(self, db) -> None:
        self._db = db

    def save(self, payload: dict) -> None:
        self._db.collection("transactions").document(payload["transaction_id"]).set(dict(payload))

    def list_for_user(self, user_id: str) -> list[dict]:
        rows = [
            doc.to_dict() or {}
            for doc in self._db.collection("transactions").where("user_id", "==", user_id).stream()
        ]
        return sorted(rows, key=lambda item: item.get("createdAt", ""), reverse=True)


class FirestoreLedger:
    """Firestore transactions. Settlement can be mirrored after the hot path."""

    defer_writes = True

    def __init__(
        self,
        db,
        accounts: FirestoreAccountStore,
        trades: FirestoreTradeStore,
        transactions: FirestoreTransactionStore,
    ) -> None:
        self._db = db
        self.accounts = accounts
        self.trades = trades
        self.transactions = transactions

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
        account_ref = self._db.collection("accounts").document(user_id)
        trade_ref = self._db.collection("trades").document(trade["trade_id"])
        txn_ref = self._db.collection("transactions").document(transaction["transaction_id"])
        open_query = (
            self._db.collection("trades")
            .where("user_id", "==", user_id)
            .where("status", "==", "OPEN")
        )

        @firestore.transactional
        def _apply(txn) -> dict:
            book = trade.get("account_type") or "DEMO"
            snap = account_ref.get(transaction=txn)
            data = snap.to_dict() or {} if snap.exists else {}
            if book == "LIVE":
                available = float(data.get("live_balance", 0.0)) if snap.exists else 0.0
            elif snap.exists:
                available = float(data.get("balance", self.accounts.initial))
            else:
                available = self.accounts.initial
            if not snap.exists:
                txn.set(
                    account_ref,
                    {
                        "uid": user_id,
                        "balance": self.accounts.initial if book != "LIVE" else available,
                        "live_balance": available if book == "LIVE" else 0.0,
                        "createdAt": _now(),
                        "updatedAt": _now(),
                    },
                )
                if book != "LIVE":
                    available = self.accounts.initial
            if stake > available:
                raise ValueError(
                    "Insufficient live balance" if book == "LIVE" else "Insufficient demo balance"
                )
            open_docs = [
                doc
                for doc in list(txn.get(open_query))
                if (doc.to_dict() or {}).get("account_type", "DEMO") == book
            ]
            if len(open_docs) >= max_open:
                raise ValueError("Maximum 10 active trades reached.")
            after = round(available - stake, 2)
            field = "live_balance" if book == "LIVE" else "balance"
            txn.set(
                account_ref,
                {"uid": user_id, field: after, "updatedAt": _now()},
                merge=True,
            )
            transaction["balanceBefore"] = available
            transaction["balanceAfter"] = after
            txn.set(trade_ref, dict(trade))
            txn.set(txn_ref, dict(transaction))
            return dict(trade)

        return _apply(self._db.transaction())

    def commit_credit(self, user_id: str, amount: float) -> float:
        if amount <= 0:
            raise ValueError("Invalid credit amount")
        account_ref = self._db.collection("accounts").document(user_id)
        txn_id = f"demo-credit-{user_id}-{_now()}"
        txn_ref = self._db.collection("transactions").document(txn_id)

        @firestore.transactional
        def _apply(txn) -> float:
            snap = account_ref.get(transaction=txn)
            if snap.exists:
                before = float((snap.to_dict() or {}).get("balance", self.accounts.initial))
            else:
                before = self.accounts.initial
            after = round(before + amount, 2)
            txn.set(
                account_ref,
                {"uid": user_id, "balance": after, "updatedAt": _now()},
                merge=True,
            )
            txn.set(
                txn_ref,
                {
                    "transaction_id": txn_id,
                    "user_id": user_id,
                    "type": "DEMO_CREDIT",
                    "amount": round(amount, 2),
                    "balanceBefore": before,
                    "balanceAfter": after,
                    "simulated": True,
                    "createdAt": _now(),
                },
            )
            return after

        return _apply(self._db.transaction())

    def commit_settle(self, trade_id: str, expiry_price: float, apply) -> dict:
        trade_ref = self._db.collection("trades").document(trade_id)

        @firestore.transactional
        def _apply(txn) -> dict:
            snap = trade_ref.get(transaction=txn)
            if not snap.exists:
                raise ValueError("Trade not found")
            trade = snap.to_dict() or {}
            updated, credit, extra = apply(trade, expiry_price)
            user_id = updated["user_id"]
            account_ref = self._db.collection("accounts").document(user_id)
            if extra is not None or credit:
                book = updated.get("account_type") or "DEMO"
                acc = account_ref.get(transaction=txn)
                acc_data = acc.to_dict() or {} if acc.exists else {}
                if book == "LIVE":
                    before = float(acc_data.get("live_balance", 0.0)) if acc.exists else 0.0
                    field = "live_balance"
                else:
                    before = (
                        float(acc_data.get("balance", self.accounts.initial))
                        if acc.exists
                        else self.accounts.initial
                    )
                    field = "balance"
                after = round(before + credit, 2)
                txn.set(
                    account_ref,
                    {"uid": user_id, field: after, "updatedAt": _now()},
                    merge=True,
                )
                if extra is not None:
                    extra["balanceBefore"] = before
                    extra["balanceAfter"] = after
                    extra["account_type"] = book
                    txn.set(
                        self._db.collection("transactions").document(extra["transaction_id"]),
                        dict(extra),
                    )
            txn.set(trade_ref, dict(updated))
            return dict(updated)

        return _apply(self._db.transaction())


class FirestoreWithdrawalStore:
    def __init__(self, db, accounts: FirestoreAccountStore) -> None:
        self._db = db
        self.accounts = accounts

    def _ref(self, request_id: str):
        return self._db.collection("withdrawals").document(request_id)

    def get(self, request_id: str) -> dict | None:
        snap = self._ref(request_id).get()
        if not snap.exists:
            return None
        return snap.to_dict()

    def list_for_user(self, user_id: str) -> list[dict]:
        rows = [
            doc.to_dict() or {}
            for doc in self._db.collection("withdrawals").where("user_id", "==", user_id).stream()
        ]
        return sorted(rows, key=lambda item: item.get("created_at", ""), reverse=True)

    def list_all(self) -> list[dict]:
        rows = [doc.to_dict() or {} for doc in self._db.collection("withdrawals").stream()]
        return sorted(rows, key=lambda item: item.get("created_at", ""), reverse=True)

    def create_pending(self, row: dict) -> tuple[dict, float]:
        from app.services.withdraw import MSG_INSUFFICIENT, MSG_PENDING, WithdrawError

        account_ref = self._db.collection("accounts").document(row["user_id"])
        withdraw_ref = self._ref(row["request_id"])

        @firestore.transactional
        def _apply(txn) -> tuple[dict, float]:
            snap = account_ref.get(transaction=txn)
            data = snap.to_dict() or {} if snap.exists else {}
            pending_id = data.get("pending_withdrawal_id")
            if pending_id:
                raise WithdrawError(MSG_PENDING, "pending")
            available = float(data.get("live_balance", 0.0)) if snap.exists else 0.0
            amount = float(row["amount_usd"])
            if amount > available:
                raise WithdrawError(MSG_INSUFFICIENT)
            after = round(available - amount, 2)
            stored = dict(row)
            stored["refunded"] = False
            txn.set(
                account_ref,
                {
                    "uid": row["user_id"],
                    "live_balance": after,
                    "pending_withdrawal_id": row["request_id"],
                    "updatedAt": _now(),
                },
                merge=True,
            )
            txn.set(withdraw_ref, stored)
            return stored, after

        return _apply(self._db.transaction())

    def approve(self, request_id: str, admin_username: str) -> dict:
        from app.services.withdraw import (
            MSG_ALREADY_REJECTED,
            MSG_NOT_FOUND,
            STATUS_PENDING,
            STATUS_REJECTED,
            STATUS_SUCCESSFUL,
            WithdrawError,
        )

        withdraw_ref = self._ref(request_id)

        @firestore.transactional
        def _apply(txn) -> dict:
            snap = withdraw_ref.get(transaction=txn)
            if not snap.exists:
                raise WithdrawError(MSG_NOT_FOUND, "not_found")
            row = snap.to_dict() or {}
            if row.get("status") == STATUS_SUCCESSFUL:
                return row
            if row.get("status") == STATUS_REJECTED:
                raise WithdrawError(MSG_ALREADY_REJECTED, "conflict")
            if row.get("status") != STATUS_PENDING:
                raise WithdrawError(MSG_ALREADY_REJECTED, "conflict")
            now = _now()
            row["status"] = STATUS_SUCCESSFUL
            row["updated_at"] = now
            row["processed_at"] = now
            row["processed_by"] = admin_username
            account_ref = self._db.collection("accounts").document(row["user_id"])
            txn.set(withdraw_ref, row)
            txn.set(
                account_ref,
                {"pending_withdrawal_id": None, "updatedAt": now},
                merge=True,
            )
            return row

        return _apply(self._db.transaction())

    def reject(self, request_id: str, admin_username: str, reason: str) -> tuple[dict, float]:
        from app.services.withdraw import (
            MSG_ALREADY_SUCCESSFUL,
            MSG_NOT_FOUND,
            STATUS_PENDING,
            STATUS_REJECTED,
            STATUS_SUCCESSFUL,
            WithdrawError,
        )

        withdraw_ref = self._ref(request_id)

        @firestore.transactional
        def _apply(txn) -> tuple[dict, float]:
            snap = withdraw_ref.get(transaction=txn)
            if not snap.exists:
                raise WithdrawError(MSG_NOT_FOUND, "not_found")
            row = snap.to_dict() or {}
            account_ref = self._db.collection("accounts").document(row["user_id"])
            acc = account_ref.get(transaction=txn)
            acc_data = acc.to_dict() or {} if acc.exists else {}
            live = float(acc_data.get("live_balance", 0.0)) if acc.exists else 0.0
            if row.get("status") == STATUS_REJECTED:
                return row, live
            if row.get("status") == STATUS_SUCCESSFUL:
                raise WithdrawError(MSG_ALREADY_SUCCESSFUL, "conflict")
            if row.get("status") != STATUS_PENDING:
                raise WithdrawError(MSG_ALREADY_SUCCESSFUL, "conflict")
            amount = float(row.get("amount_usd") or 0)
            if not row.get("refunded"):
                live = round(live + amount, 2)
                row["refunded"] = True
            now = _now()
            row["status"] = STATUS_REJECTED
            row["rejection_reason"] = reason
            row["updated_at"] = now
            row["processed_at"] = now
            row["processed_by"] = admin_username
            txn.set(withdraw_ref, row)
            txn.set(
                account_ref,
                {
                    "live_balance": live,
                    "pending_withdrawal_id": None,
                    "updatedAt": now,
                },
                merge=True,
            )
            return row, live

        return _apply(self._db.transaction())


class FirestoreDepositStore:
    def __init__(self, db, accounts: FirestoreAccountStore) -> None:
        self._db = db
        self.accounts = accounts

    def _ref(self, request_id: str):
        return self._db.collection("deposits").document(request_id)

    def get(self, request_id: str) -> dict | None:
        snap = self._ref(request_id).get()
        if not snap.exists:
            return None
        return snap.to_dict()

    def list_for_user(self, user_id: str) -> list[dict]:
        rows = [
            doc.to_dict() or {}
            for doc in self._db.collection("deposits").where("user_id", "==", user_id).stream()
        ]
        return sorted(rows, key=lambda item: item.get("created_at", ""), reverse=True)

    def list_all(self) -> list[dict]:
        rows = [doc.to_dict() or {} for doc in self._db.collection("deposits").stream()]
        return sorted(rows, key=lambda item: item.get("created_at", ""), reverse=True)

    def create_pending(self, row: dict) -> dict:
        stored = dict(row)
        stored["credited"] = False
        self._ref(stored["request_id"]).set(stored)
        return stored

    def approve(self, request_id: str, admin_username: str) -> tuple[dict, float]:
        from app.services.deposit import (
            MSG_ALREADY_REJECTED,
            MSG_NOT_FOUND,
            STATUS_PENDING,
            STATUS_REJECTED,
            STATUS_SUCCESSFUL,
            DepositError,
        )

        deposit_ref = self._ref(request_id)

        @firestore.transactional
        def _apply(txn) -> tuple[dict, float]:
            snap = deposit_ref.get(transaction=txn)
            if not snap.exists:
                raise DepositError(MSG_NOT_FOUND, "not_found")
            row = snap.to_dict() or {}
            account_ref = self._db.collection("accounts").document(row["user_id"])
            acc = account_ref.get(transaction=txn)
            acc_data = acc.to_dict() or {} if acc.exists else {}
            live = float(acc_data.get("live_balance", 0.0)) if acc.exists else 0.0
            if row.get("status") == STATUS_SUCCESSFUL:
                return row, live
            if row.get("status") == STATUS_REJECTED:
                raise DepositError(MSG_ALREADY_REJECTED, "conflict")
            if row.get("status") != STATUS_PENDING:
                raise DepositError(MSG_ALREADY_REJECTED, "conflict")
            if not row.get("credited"):
                live = round(live + float(row.get("amount_usd") or 0), 2)
                row["credited"] = True
            now = _now()
            row["status"] = STATUS_SUCCESSFUL
            row["updated_at"] = now
            row["processed_at"] = now
            row["processed_by"] = admin_username
            txn.set(deposit_ref, row)
            txn.set(
                account_ref,
                {"uid": row["user_id"], "live_balance": live, "updatedAt": now},
                merge=True,
            )
            return row, live

        return _apply(self._db.transaction())

    def reject(self, request_id: str, admin_username: str, reason: str) -> tuple[dict, float]:
        from app.services.deposit import (
            MSG_ALREADY_SUCCESSFUL,
            MSG_NOT_FOUND,
            STATUS_PENDING,
            STATUS_REJECTED,
            STATUS_SUCCESSFUL,
            DepositError,
        )

        deposit_ref = self._ref(request_id)

        @firestore.transactional
        def _apply(txn) -> tuple[dict, float]:
            snap = deposit_ref.get(transaction=txn)
            if not snap.exists:
                raise DepositError(MSG_NOT_FOUND, "not_found")
            row = snap.to_dict() or {}
            account_ref = self._db.collection("accounts").document(row["user_id"])
            acc = account_ref.get(transaction=txn)
            acc_data = acc.to_dict() or {} if acc.exists else {}
            live = float(acc_data.get("live_balance", 0.0)) if acc.exists else 0.0
            if row.get("status") == STATUS_REJECTED:
                return row, live
            if row.get("status") == STATUS_SUCCESSFUL or row.get("credited"):
                raise DepositError(MSG_ALREADY_SUCCESSFUL, "conflict")
            if row.get("status") != STATUS_PENDING:
                raise DepositError(MSG_ALREADY_SUCCESSFUL, "conflict")
            now = _now()
            row["status"] = STATUS_REJECTED
            row["rejection_reason"] = reason
            row["credited"] = False
            row["updated_at"] = now
            row["processed_at"] = now
            row["processed_by"] = admin_username
            txn.set(deposit_ref, row)
            return row, live

        return _apply(self._db.transaction())


def build_firestore_stores(initial_balance: float, db=None):
    client = db or firestore_client()
    accounts = FirestoreAccountStore(client, initial_balance)
    trades = FirestoreTradeStore(client)
    transactions = FirestoreTransactionStore(client)
    ledger = FirestoreLedger(client, accounts, trades, transactions)
    withdrawals = FirestoreWithdrawalStore(client, accounts)
    deposits = FirestoreDepositStore(client, accounts)
    return accounts, trades, transactions, ledger, withdrawals, deposits
