from __future__ import annotations

import re
import uuid
from datetime import datetime, timezone
from typing import Any

from app.core.runtime import get_trading

USD_TO_BDT = 124.0
MIN_CRYPTO = 50.0
MAX_CRYPTO = 10_000.0
MIN_P2P_BDT = 5_000.0
MAX_P2P_BDT = 50_000.0

STATUS_PENDING = "Pending"
STATUS_SUCCESSFUL = "Successful"
STATUS_REJECTED = "Rejected"

METHOD_BTC = "btc"
METHOD_USDT_TRC20 = "usdt_trc20"
METHOD_ETH_ERC20 = "eth_erc20"
METHOD_BKASH = "bkash"
METHOD_NAGAD = "nagad"
CRYPTO_METHODS = (METHOD_BTC, METHOD_USDT_TRC20, METHOD_ETH_ERC20)
P2P_METHODS = (METHOD_BKASH, METHOD_NAGAD)
WITHDRAW_METHODS = CRYPTO_METHODS + P2P_METHODS

MSG_MIN = "Minimum withdrawal amount is $50.00."
MSG_MAX = "Maximum withdrawal amount is $10,000.00."
MSG_P2P_MIN = "Minimum P2P withdrawal is ৳5,000.00."
MSG_P2P_MAX = "Maximum P2P withdrawal is ৳50,000.00."
MSG_INSUFFICIENT = "Insufficient Live Balance."
MSG_METHOD = "Please select a payment method."
MSG_ADDRESS_REQUIRED = "Please enter your payment address."
MSG_DETAILS_REQUIRED = "Please enter your payment details."
MSG_BTC = "Please enter a valid Bitcoin wallet address."
MSG_TRC20 = "Please enter a valid USDT TRC20 wallet address."
MSG_ETH = "Please enter a valid Ethereum ERC20 wallet address."
MSG_BKASH = "Please enter a valid bKash number."
MSG_NAGAD = "Please enter a valid Nagad number."
MSG_AMOUNT_REQUIRED = "Please enter a withdrawal amount."
MSG_AMOUNT_INVALID = "Please enter a valid withdrawal amount."
MSG_PENDING = "You already have a pending withdrawal request."
MSG_NOT_FOUND = "Withdrawal request not found."
MSG_FORBIDDEN = "Withdrawal request not found."
MSG_REASON_REQUIRED = "Please enter a rejection reason."
MSG_ALREADY_SUCCESSFUL = "This withdrawal has already been approved."
MSG_ALREADY_REJECTED = "This withdrawal has already been rejected."
MSG_INVALID_TRANSITION = "This withdrawal can no longer be updated."
SUBMITTED_MESSAGE = (
    "🎉 Withdrawal Request Submitted!\n"
    "Thank you! Your withdrawal request has been successfully received.\n"
    "Your withdrawal will be processed within 15 minutes to 7 days.\n"
    "Thank you."
)

_BASE58 = re.compile(r"^[1-9A-HJ-NP-Za-km-z]+$")
_BTC_LEGACY = re.compile(r"^[13][1-9A-HJ-NP-Za-km-z]{25,33}$")
_BTC_BECH32 = re.compile(r"^bc1[qpzry9x8gf2tvdw0s3jn54khce6mua7l]{11,71}$")
_TRON = re.compile(r"^T[1-9A-HJ-NP-Za-km-z]{33}$")
_ETH = re.compile(r"^0x[0-9a-fA-F]{40}$")
_BD_MOBILE = re.compile(r"^(?:\+?8801|01)[3-9]\d{8}$")

_METHOD_ALIASES = {
    "btc": METHOD_BTC,
    "bitcoin": METHOD_BTC,
    "usdt_trc20": METHOD_USDT_TRC20,
    "usdttrc20": METHOD_USDT_TRC20,
    "usdt": METHOD_USDT_TRC20,
    "eth": METHOD_ETH_ERC20,
    "eth_erc20": METHOD_ETH_ERC20,
    "ethereum": METHOD_ETH_ERC20,
    "bkash": METHOD_BKASH,
    "nagad": METHOD_NAGAD,
}


class WithdrawError(Exception):
    def __init__(self, message: str, code: str = "validation") -> None:
        super().__init__(message)
        self.message = message
        self.code = code


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def usd_to_bdt(amount_usd: float) -> float:
    return round(float(amount_usd) * USD_TO_BDT, 2)


def normalize_method(raw: Any) -> str | None:
    if raw is None:
        return None
    key = str(raw).strip().lower().replace("-", "_").replace(" ", "")
    if not key:
        return None
    return _METHOD_ALIASES.get(key)


def parse_usd_amount(raw: Any) -> float | str:
    if raw is None or (isinstance(raw, str) and not raw.strip()):
        return MSG_AMOUNT_REQUIRED
    try:
        value = float(raw)
    except (TypeError, ValueError):
        return MSG_AMOUNT_INVALID
    if value != value or value in (float("inf"), float("-inf")):
        return MSG_AMOUNT_INVALID
    if value <= 0:
        return MSG_AMOUNT_INVALID
    return round(value, 2)


def validate_amount(method: str, amount_usd: float) -> str | None:
    if method in CRYPTO_METHODS:
        if amount_usd < MIN_CRYPTO:
            return MSG_MIN
        if amount_usd > MAX_CRYPTO:
            return MSG_MAX
        return None
    if method in P2P_METHODS:
        bdt = usd_to_bdt(amount_usd)
        if bdt < MIN_P2P_BDT:
            return MSG_P2P_MIN
        if bdt > MAX_P2P_BDT:
            return MSG_P2P_MAX
        return None
    return MSG_METHOD


def validate_btc_address(address: str) -> bool:
    value = address.strip()
    if _BTC_LEGACY.fullmatch(value):
        return True
    return bool(_BTC_BECH32.fullmatch(value.lower()))


def validate_trc20_address(address: str) -> bool:
    value = address.strip()
    return bool(_TRON.fullmatch(value) and _BASE58.fullmatch(value))


def validate_eth_address(address: str) -> bool:
    return bool(_ETH.fullmatch(address.strip()))


def validate_bd_mobile(number: str) -> bool:
    compact = re.sub(r"[\s-]", "", number.strip())
    return bool(_BD_MOBILE.fullmatch(compact))


def validate_payment_details(method: str, details: Any) -> str | None:
    if details is None or not str(details).strip():
        return MSG_DETAILS_REQUIRED if method in P2P_METHODS else MSG_ADDRESS_REQUIRED
    value = str(details).strip()
    if method == METHOD_BTC:
        return None if validate_btc_address(value) else MSG_BTC
    if method == METHOD_USDT_TRC20:
        return None if validate_trc20_address(value) else MSG_TRC20
    if method == METHOD_ETH_ERC20:
        return None if validate_eth_address(value) else MSG_ETH
    if method == METHOD_BKASH:
        return None if validate_bd_mobile(value) else MSG_BKASH
    if method == METHOD_NAGAD:
        return None if validate_bd_mobile(value) else MSG_NAGAD
    return MSG_METHOD


def normalize_payment_details(method: str, details: str) -> str:
    value = details.strip()
    if method in P2P_METHODS:
        return re.sub(r"[\s-]", "", value)
    return value


def public_request(row: dict, *, admin: bool = False) -> dict:
    payload = {
        "request_id": row.get("request_id"),
        "amount_usd": row.get("amount_usd"),
        "amount_bdt": row.get("amount_bdt"),
        "currency": row.get("currency"),
        "payment_method": row.get("payment_method"),
        "payment_details": row.get("payment_details"),
        "status": row.get("status"),
        "created_at": row.get("created_at"),
        "updated_at": row.get("updated_at"),
        "rejection_reason": row.get("rejection_reason"),
        "processed_at": row.get("processed_at"),
    }
    if admin:
        payload["user_id"] = row.get("user_id")
        payload["user_email"] = row.get("user_email") or ""
        payload["user_name"] = row.get("user_name") or ""
        payload["processed_by"] = row.get("processed_by")
    return payload


def _validate_new_request(amount: Any, method: Any, details: Any) -> tuple[float, str, str, float | None]:
    selected = normalize_method(method)
    if selected is None:
        raise WithdrawError(MSG_METHOD)
    parsed = parse_usd_amount(amount)
    if isinstance(parsed, str):
        raise WithdrawError(parsed)
    amount_error = validate_amount(selected, parsed)
    if amount_error:
        raise WithdrawError(amount_error)
    details_error = validate_payment_details(selected, details)
    if details_error:
        raise WithdrawError(details_error)
    normalized = normalize_payment_details(selected, str(details))
    bdt = usd_to_bdt(parsed) if selected in P2P_METHODS else None
    return parsed, selected, normalized, bdt


def create_withdrawal(
    *,
    user_id: str,
    amount: Any,
    method: Any,
    payment_details: Any,
) -> dict:
    trading = get_trading()
    trading.ensure_account(user_id)
    amount_usd, selected, details, amount_bdt = _validate_new_request(
        amount, method, payment_details
    )
    profile = trading.profile(user_id) or {}
    request_id = str(uuid.uuid4())
    now = _now()
    row = {
        "request_id": request_id,
        "user_id": user_id,
        "user_email": profile.get("email") or "",
        "user_name": profile.get("displayName") or "",
        "amount_usd": amount_usd,
        "amount_bdt": amount_bdt,
        "currency": "BDT" if selected in P2P_METHODS else "USD",
        "payment_method": selected,
        "payment_details": details,
        "status": STATUS_PENDING,
        "created_at": now,
        "updated_at": now,
        "rejection_reason": None,
        "processed_at": None,
        "processed_by": None,
    }
    created, live_after = trading.withdrawals.create_pending(row)
    trading.note_live_balance(user_id, live_after)
    return {
        "ok": True,
        "request_created": True,
        "balance_deducted": True,
        "live_balance": live_after,
        "message": SUBMITTED_MESSAGE,
        "request": public_request(created),
    }


def list_user_withdrawals(user_id: str) -> list[dict]:
    trading = get_trading()
    trading.ensure_account(user_id)
    return [public_request(row) for row in trading.withdrawals.list_for_user(user_id)]


def get_user_withdrawal(user_id: str, request_id: str) -> dict:
    trading = get_trading()
    row = trading.withdrawals.get(request_id)
    if row is None or row.get("user_id") != user_id:
        raise WithdrawError(MSG_FORBIDDEN, "not_found")
    return public_request(row)


def list_admin_withdrawals(*, status: str | None = None, search: str | None = None) -> list[dict]:
    trading = get_trading()
    rows = trading.withdrawals.list_all()
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
            or query in str(row.get("user_name", "")).lower()
        ]
    return [public_request(row, admin=True) for row in rows]


def approve_withdrawal(request_id: str, admin_username: str) -> dict:
    trading = get_trading()
    updated = trading.withdrawals.approve(request_id, admin_username)
    return {"ok": True, "request": public_request(updated, admin=True)}


def reject_withdrawal(request_id: str, admin_username: str, reason: Any) -> dict:
    if reason is None or not str(reason).strip():
        raise WithdrawError(MSG_REASON_REQUIRED)
    trading = get_trading()
    updated, live_after = trading.withdrawals.reject(
        request_id, admin_username, str(reason).strip()
    )
    trading.note_live_balance(updated["user_id"], live_after)
    return {"ok": True, "request": public_request(updated, admin=True)}
