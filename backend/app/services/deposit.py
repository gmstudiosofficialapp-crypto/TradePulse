from __future__ import annotations

import re
import uuid
from datetime import datetime, timezone
from typing import Any

from app.core.runtime import get_trading

MIN_DEPOSIT = 10.0
MAX_DEPOSIT = 10_000.0

STATUS_PENDING = "Pending"
STATUS_SUCCESSFUL = "Successful"
STATUS_REJECTED = "Rejected"

METHOD_BTC = "btc"
METHOD_USDT_TRC20 = "usdt_trc20"
METHOD_ETH_ERC20 = "eth_erc20"
DEPOSIT_METHODS = (METHOD_BTC, METHOD_USDT_TRC20, METHOD_ETH_ERC20)

MSG_MIN = "Minimum deposit is $10.00."
MSG_MAX = "Maximum deposit is $10,000.00."
MSG_AMOUNT_REQUIRED = "Please enter a deposit amount."
MSG_AMOUNT_INVALID = "Please enter a valid deposit amount."
MSG_METHOD = "Please select a payment method."
MSG_TXID_REQUIRED = "Enter a transaction ID."
MSG_TXID_INVALID = "Enter a valid transaction ID."
MSG_NOT_FOUND = "Deposit request not found."
MSG_FORBIDDEN = "Deposit request not found."
MSG_REASON_REQUIRED = "Please enter a rejection reason."
MSG_ALREADY_SUCCESSFUL = "This deposit has already been approved."
MSG_ALREADY_REJECTED = "This deposit has already been rejected."
SUBMITTED_MESSAGE = (
    "Deposit request submitted.\n"
    "Your request is under review.\n"
    "Live Balance is not credited until an administrator approves it."
)

_TXID = re.compile(r"^[A-Za-z0-9]{6,128}$")
_METHOD_ALIASES = {
    "btc": METHOD_BTC,
    "bitcoin": METHOD_BTC,
    "usdt_trc20": METHOD_USDT_TRC20,
    "usdttrc20": METHOD_USDT_TRC20,
    "usdt": METHOD_USDT_TRC20,
    "eth": METHOD_ETH_ERC20,
    "eth_erc20": METHOD_ETH_ERC20,
    "ethereum": METHOD_ETH_ERC20,
}
_NETWORKS = {
    METHOD_BTC: "Bitcoin",
    METHOD_USDT_TRC20: "TRON (TRC20)",
    METHOD_ETH_ERC20: "ERC20",
}


class DepositError(Exception):
    def __init__(self, message: str, code: str = "validation") -> None:
        super().__init__(message)
        self.message = message
        self.code = code


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def normalize_method(raw: Any) -> str | None:
    if raw is None:
        return None
    key = str(raw).strip().lower().replace("-", "_").replace(" ", "")
    if not key:
        return None
    return _METHOD_ALIASES.get(key)


def parse_amount(raw: Any) -> float | str:
    if raw is None or (isinstance(raw, str) and not raw.strip()):
        return MSG_AMOUNT_REQUIRED
    try:
        value = float(raw)
    except (TypeError, ValueError):
        return MSG_AMOUNT_INVALID
    if value != value or value in (float("inf"), float("-inf")) or value <= 0:
        return MSG_AMOUNT_INVALID
    value = round(value, 2)
    if value < MIN_DEPOSIT:
        return MSG_MIN
    if value > MAX_DEPOSIT:
        return MSG_MAX
    return value


def normalize_txid(raw: Any) -> str | str:
    if raw is None or not str(raw).strip():
        return MSG_TXID_REQUIRED
    value = re.sub(r"\s+", "", str(raw).strip())
    if not _TXID.fullmatch(value):
        return MSG_TXID_INVALID
    return value


def public_request(row: dict, *, admin: bool = False) -> dict:
    payload = {
        "request_id": row.get("request_id"),
        "amount_usd": row.get("amount_usd"),
        "currency": "USD",
        "payment_method": row.get("payment_method"),
        "network": row.get("network"),
        "txid": row.get("txid"),
        "status": row.get("status"),
        "created_at": row.get("created_at"),
        "updated_at": row.get("updated_at"),
        "rejection_reason": row.get("rejection_reason"),
        "processed_at": row.get("processed_at"),
        "credited": bool(row.get("credited")),
    }
    if admin:
        payload["user_id"] = row.get("user_id")
        payload["user_email"] = row.get("user_email") or ""
        payload["user_name"] = row.get("user_name") or ""
        payload["processed_by"] = row.get("processed_by")
    return payload


def create_deposit(*, user_id: str, amount: Any, method: Any, txid: Any) -> dict:
    trading = get_trading()
    trading.ensure_account(user_id)
    selected = normalize_method(method)
    if selected is None:
        raise DepositError(MSG_METHOD)
    parsed = parse_amount(amount)
    if isinstance(parsed, str):
        raise DepositError(parsed)
    reference = normalize_txid(txid)
    if reference in (MSG_TXID_REQUIRED, MSG_TXID_INVALID):
        raise DepositError(reference)
    before = trading.live_balance(user_id)
    profile = trading.profile(user_id) or {}
    now = _now()
    row = {
        "request_id": str(uuid.uuid4()),
        "user_id": user_id,
        "user_email": profile.get("email") or "",
        "user_name": profile.get("displayName") or "",
        "amount_usd": parsed,
        "currency": "USD",
        "payment_method": selected,
        "network": _NETWORKS[selected],
        "txid": reference,
        "status": STATUS_PENDING,
        "credited": False,
        "created_at": now,
        "updated_at": now,
        "rejection_reason": None,
        "processed_at": None,
        "processed_by": None,
    }
    created = trading.deposits.create_pending(row)
    after = trading.live_balance(user_id)
    if after != before:
        raise DepositError("Deposit submission must not change Live Balance.", "integrity")
    return {
        "ok": True,
        "request_created": True,
        "balance_credited": False,
        "live_balance": after,
        "message": SUBMITTED_MESSAGE,
        "request": public_request(created),
    }


def list_user_deposits(user_id: str) -> list[dict]:
    trading = get_trading()
    trading.ensure_account(user_id)
    return [public_request(row) for row in trading.deposits.list_for_user(user_id)]


def get_user_deposit(user_id: str, request_id: str) -> dict:
    row = get_trading().deposits.get(request_id)
    if row is None or row.get("user_id") != user_id:
        raise DepositError(MSG_FORBIDDEN, "not_found")
    return public_request(row)


def list_admin_deposits(*, status: str | None = None, search: str | None = None) -> list[dict]:
    rows = get_trading().deposits.list_all()
    if status:
        wanted = status.strip()
        rows = [row for row in rows if row.get("status") == wanted]
    query = (search or "").strip().lower()
    if query:
        rows = [
            row
            for row in rows
            if query in str(row.get("request_id", "")).lower()
            or query in str(row.get("user_id", "")).lower()
            or query in str(row.get("user_email", "")).lower()
            or query in str(row.get("txid", "")).lower()
        ]
    return [public_request(row, admin=True) for row in rows]


def approve_deposit(request_id: str, admin_username: str) -> dict:
    trading = get_trading()
    updated, live_after = trading.deposits.approve(request_id, admin_username)
    trading.note_live_balance(updated["user_id"], live_after)
    return {
        "ok": True,
        "balance_credited": bool(updated.get("credited")),
        "live_balance": live_after,
        "request": public_request(updated, admin=True),
    }


def reject_deposit(request_id: str, admin_username: str, reason: Any) -> dict:
    if reason is None or not str(reason).strip():
        raise DepositError(MSG_REASON_REQUIRED)
    trading = get_trading()
    updated, live_after = trading.deposits.reject(
        request_id, admin_username, str(reason).strip()
    )
    trading.note_live_balance(updated["user_id"], live_after)
    return {
        "ok": True,
        "balance_credited": False,
        "live_balance": live_after,
        "request": public_request(updated, admin=True),
    }
