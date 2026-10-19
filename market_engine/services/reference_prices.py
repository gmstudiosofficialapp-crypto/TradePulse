from __future__ import annotations

import json
import os
import urllib.error
import urllib.request
from typing import Callable

from market_engine.config.assets import ASSET_CONFIGS

BINANCE_SYMBOLS = {
    "BTC/USD-OTC": "BTCUSDT",
    "ETH/USD-OTC": "ETHUSDT",
    "SOL/USD-OTC": "SOLUSDT",
    "XRP/USD-OTC": "XRPUSDT",
    "DOGE/USD-OTC": "DOGEUSDT",
}

FRANKFURTER_PAIRS = {
    "EUR/USD-OTC": ("EUR", "USD"),
    "GBP/USD-OTC": ("GBP", "USD"),
    "USD/JPY-OTC": ("USD", "JPY"),
    "AUD/USD-OTC": ("AUD", "USD"),
    "USD/CAD-OTC": ("USD", "CAD"),
    "USD/CHF-OTC": ("USD", "CHF"),
    "EUR/GBP-OTC": ("EUR", "GBP"),
    "EUR/JPY-OTC": ("EUR", "JPY"),
    "GBP/JPY-OTC": ("GBP", "JPY"),
    "AUD/JPY-OTC": ("AUD", "JPY"),
}

UNSUPPORTED_LIVE_REFERENCE = {
    "GOLD/USD-OTC": "No free gold spot feed is configured",
    "SILVER/USD-OTC": "No free silver spot feed is configured",
    "NASDAQ-OTC": "No free Nasdaq feed is configured",
    "S&P500-OTC": "No free S&P 500 feed is configured",
    "DOW JONES-OTC": "No free Dow Jones feed is configured",
}

HttpGet = Callable[[str], object]


def reference_fetch_enabled() -> bool:
    raw = os.getenv("TRADEPULSE_REFERENCE_PRICES", "").strip().lower()
    if raw in {"0", "false", "off", "no"}:
        return False
    if raw in {"1", "true", "on", "yes"}:
        return True
    return bool(os.getenv("RENDER"))


def is_valid_price(value: object) -> bool:
    try:
        price = float(value)
    except (TypeError, ValueError):
        return False
    return price == price and price not in (float("inf"), float("-inf")) and price > 0


def normalize_binance_symbol(otc_symbol: str) -> str | None:
    return BINANCE_SYMBOLS.get(otc_symbol)


def _default_http_get(url: str) -> object:
    request = urllib.request.Request(url, headers={"User-Agent": "TradePulse/1.0"})
    with urllib.request.urlopen(request, timeout=3.5) as response:
        payload = json.loads(response.read().decode("utf-8"))
    if not isinstance(payload, (dict, list)):
        raise ValueError("invalid payload")
    return payload


def fetch_binance_usd_prices(http_get: HttpGet | None = None) -> dict[str, float]:
    getter = http_get or _default_http_get
    mapped: dict[str, float] = {}
    try:
        raw = getter("https://api.binance.com/api/v3/ticker/price")
    except (urllib.error.URLError, TimeoutError, ValueError, json.JSONDecodeError, OSError):
        return mapped
    if isinstance(raw, list):
        rows = raw
    elif isinstance(raw, dict) and isinstance(raw.get("items"), list):
        rows = raw["items"]
    else:
        rows = []
    by_symbol = {
        str(item.get("symbol")): item.get("price")
        for item in rows
        if isinstance(item, dict)
    }
    for otc, binance in BINANCE_SYMBOLS.items():
        price = by_symbol.get(binance)
        if is_valid_price(price):
            mapped[otc] = float(price)
    return mapped


def _cross_rate(rates: dict, base: str, quote: str) -> float | None:
    if base == "USD":
        value = rates.get(quote)
        return float(value) if is_valid_price(value) else None
    if quote == "USD":
        value = rates.get(base)
        return (1.0 / float(value)) if is_valid_price(value) else None
    left = rates.get(base)
    right = rates.get(quote)
    if is_valid_price(left) and is_valid_price(right):
        return float(right) / float(left)
    return None


def fetch_forex_usd_prices(http_get: HttpGet | None = None) -> dict[str, float]:
    getter = http_get or _default_http_get
    mapped: dict[str, float] = {}
    try:
        raw = getter("https://api.frankfurter.app/latest?from=USD")
    except (urllib.error.URLError, TimeoutError, ValueError, json.JSONDecodeError, OSError):
        return mapped
    rates = raw.get("rates") if isinstance(raw, dict) else None
    if not isinstance(rates, dict):
        return mapped
    for otc, (base, quote) in FRANKFURTER_PAIRS.items():
        price = _cross_rate(rates, base, quote)
        if price is not None and is_valid_price(price):
            mapped[otc] = price
    return mapped


def collect_reference_prices(http_get: HttpGet | None = None) -> dict[str, dict]:
    prices = {
        **fetch_binance_usd_prices(http_get),
        **fetch_forex_usd_prices(http_get),
    }
    report: dict[str, dict] = {}
    for symbol in ASSET_CONFIGS:
        if symbol in prices:
            report[symbol] = {
                "price": prices[symbol],
                "source": "binance" if symbol in BINANCE_SYMBOLS else "frankfurter",
                "quote": "USD" if symbol.endswith("USD-OTC") or "/USD" in symbol else "cross",
            }
        elif symbol in UNSUPPORTED_LIVE_REFERENCE:
            report[symbol] = {
                "price": None,
                "source": "catalog_fallback",
                "reason": UNSUPPORTED_LIVE_REFERENCE[symbol],
            }
        else:
            report[symbol] = {
                "price": None,
                "source": "unavailable",
                "reason": "No reference quote was returned",
            }
    return report
