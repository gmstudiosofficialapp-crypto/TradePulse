from __future__ import annotations

import re
from typing import Any

MIN_WITHDRAWAL = 50.0
MAX_WITHDRAWAL = 10_000.0

METHOD_BTC = "btc"
METHOD_USDT_TRC20 = "usdt_trc20"
METHOD_ETH_ERC20 = "eth_erc20"
WITHDRAW_METHODS = (METHOD_BTC, METHOD_USDT_TRC20, METHOD_ETH_ERC20)

MSG_MIN = "Minimum withdrawal amount is $50.00."
MSG_MAX = "Maximum withdrawal amount is $10,000.00."
MSG_INSUFFICIENT = "Insufficient Live Balance."
MSG_METHOD = "Please select a payment method."
MSG_ADDRESS_REQUIRED = "Please enter your payment address."
MSG_BTC = "Please enter a valid Bitcoin wallet address."
MSG_TRC20 = "Please enter a valid USDT TRC20 wallet address."
MSG_ETH = "Please enter a valid Ethereum ERC20 wallet address."
MSG_AMOUNT_REQUIRED = "Please enter a withdrawal amount."
MSG_AMOUNT_INVALID = "Please enter a valid withdrawal amount."
DEPOSIT_REQUIRED_MESSAGE = (
    "⚠️ Your account is currently not eligible for withdrawal.\n"
    "Please deposit a minimum of $50 before making a withdrawal.\n"
    "Once the $50 deposit is completed, you will be able to submit a withdrawal request."
)

_BASE58 = re.compile(r"^[1-9A-HJ-NP-Za-km-z]+$")
_BTC_LEGACY = re.compile(r"^[13][1-9A-HJ-NP-Za-km-z]{25,33}$")
_BTC_BECH32 = re.compile(r"^bc1[qpzry9x8gf2tvdw0s3jn54khce6mua7l]{11,71}$")
_TRON = re.compile(r"^T[1-9A-HJ-NP-Za-km-z]{33}$")
_ETH = re.compile(r"^0x[0-9a-fA-F]{40}$")

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


def verified_deposit_total(user_id: str) -> float | None:
    """Future Deposit System hook. None means deposits are not verified yet."""
    del user_id
    return None


def is_withdrawal_eligible(user_id: str) -> bool:
    verified = verified_deposit_total(user_id)
    if verified is None:
        return False
    return verified >= MIN_WITHDRAWAL


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
    if value != value or value in (float("inf"), float("-inf")):
        return MSG_AMOUNT_INVALID
    if value < MIN_WITHDRAWAL:
        return MSG_MIN
    if value > MAX_WITHDRAWAL:
        return MSG_MAX
    return round(value, 2)


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


def validate_address(method: str, address: Any) -> str | None:
    if address is None or not str(address).strip():
        return MSG_ADDRESS_REQUIRED
    value = str(address).strip()
    if method == METHOD_BTC:
        return None if validate_btc_address(value) else MSG_BTC
    if method == METHOD_USDT_TRC20:
        return None if validate_trc20_address(value) else MSG_TRC20
    if method == METHOD_ETH_ERC20:
        return None if validate_eth_address(value) else MSG_ETH
    return MSG_METHOD


def preview_withdrawal(
    *,
    user_id: str,
    live_balance: float,
    amount: Any,
    method: Any,
    address: Any,
) -> dict:
    parsed = parse_amount(amount)
    if isinstance(parsed, str):
        return _error(parsed, live_balance)

    selected = normalize_method(method)
    if selected is None:
        return _error(MSG_METHOD, live_balance)

    address_error = validate_address(selected, address)
    if address_error:
        return _error(address_error, live_balance)

    available = round(float(live_balance), 2)
    if parsed > available:
        return _error(MSG_INSUFFICIENT, available)

    if not is_withdrawal_eligible(user_id):
        return {
            "ok": True,
            "form_valid": True,
            "eligible": False,
            "reason": "deposit_required",
            "message": DEPOSIT_REQUIRED_MESSAGE,
            "request_created": False,
            "balance_deducted": False,
            "deposit_recorded": False,
            "live_balance": available,
            "amount": parsed,
            "method": selected,
        }

    return {
        "ok": True,
        "form_valid": True,
        "eligible": True,
        "reason": "ready",
        "message": "",
        "request_created": False,
        "balance_deducted": False,
        "deposit_recorded": False,
        "live_balance": available,
        "amount": parsed,
        "method": selected,
    }


def _error(message: str, live_balance: float) -> dict:
    return {
        "ok": False,
        "form_valid": False,
        "eligible": False,
        "reason": "validation",
        "message": message,
        "request_created": False,
        "balance_deducted": False,
        "deposit_recorded": False,
        "live_balance": round(float(live_balance), 2),
    }
