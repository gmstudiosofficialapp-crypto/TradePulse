from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from firebase_admin import firestore

from app.core.firebase_admin_app import firestore_client

def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


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

    def ensure_user(self, user_id: str, email: str = "", name: str = "") -> dict:
        user_ref = self._user_ref(user_id)
        account_ref = self._account_ref(user_id)
        user_snap = user_ref.get()
        account_snap = account_ref.get()
        now = _now()
        if user_snap.exists:
            row = user_snap.to_dict() or {}
            updates: dict[str, Any] = {"updatedAt": now}
            if email:
                updates["email"] = email
            if name:
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
        if not account_snap.exists:
            account_ref.set(
                {
                    "uid": user_id,
                    "balance": self.initial,
                    "createdAt": now,
                    "updatedAt": now,
                }
            )
        return row

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
            snap = account_ref.get(transaction=txn)
            if snap.exists:
                available = float((snap.to_dict() or {}).get("balance", self.accounts.initial))
            else:
                available = self.accounts.initial
                txn.set(
                    account_ref,
                    {
                        "uid": user_id,
                        "balance": available,
                        "createdAt": _now(),
                        "updatedAt": _now(),
                    },
                )
            if stake > available:
                raise ValueError("Insufficient demo balance")
            open_docs = list(txn.get(open_query))
            if len(open_docs) >= max_open:
                raise ValueError("Maximum 10 active trades reached.")
            after = round(available - stake, 2)
            txn.set(
                account_ref,
                {"uid": user_id, "balance": after, "updatedAt": _now()},
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
                acc = account_ref.get(transaction=txn)
                before = (
                    float((acc.to_dict() or {}).get("balance", self.accounts.initial))
                    if acc.exists
                    else self.accounts.initial
                )
                after = round(before + credit, 2)
                txn.set(
                    account_ref,
                    {"uid": user_id, "balance": after, "updatedAt": _now()},
                    merge=True,
                )
                if extra is not None:
                    extra["balanceBefore"] = before
                    extra["balanceAfter"] = after
                    txn.set(
                        self._db.collection("transactions").document(extra["transaction_id"]),
                        dict(extra),
                    )
            txn.set(trade_ref, dict(updated))
            return dict(updated)

        return _apply(self._db.transaction())


def build_firestore_stores(initial_balance: float, db=None):
    client = db or firestore_client()
    accounts = FirestoreAccountStore(client, initial_balance)
    trades = FirestoreTradeStore(client)
    transactions = FirestoreTransactionStore(client)
    ledger = FirestoreLedger(client, accounts, trades, transactions)
    return accounts, trades, transactions, ledger
