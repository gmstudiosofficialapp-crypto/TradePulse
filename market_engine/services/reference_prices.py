from __future__ import annotations

import json
import os
import urllib.error
import urllib.parse
import urllib.request
from typing import Callable

from market_engine.config.assets import ASSET_CONFIGS

COINGECKO_IDS = {
    "BTC/USD-OTC": "bitcoin",
    "ETH/USD-OTC": "ethereum",
    "SOL/USD-OTC": "solana",
    "XRP/USD-OTC": "ripple",
    "DOGE/USD-OTC": "dogecoin",
}

BINANCE_SYMBOLS = {
    "BTC/USD-OTC": "BTCUSDT",
    "ETH/USD-OTC": "ETHUSDT",
    "SOL/USD-OTC": "SOLUSDT",
    "XRP/USD-OTC": "XRPUSDT",
    "DOGE/USD-OTC": "DOGEUSDT",
}

KRAKEN_PAIRS = {
    "BTC/USD-OTC": ("XBTUSD", "XXBTZUSD"),
    "ETH/USD-OTC": ("ETHUSD", "XETHZUSD"),
    "SOL/USD-OTC": ("SOLUSD", "SOLUSD"),
    "XRP/USD-OTC": ("XRPUSD", "XXRPZUSD"),
    "DOGE/USD-OTC": ("XDGUSD", "XXDGZUSD"),
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

YAHOO_METALS_INDICES = {
    "GOLD/USD-OTC": "GC=F",
    "SILVER/USD-OTC": "SI=F",
    "NASDAQ-OTC": "^IXIC",
    "S&P500-OTC": "^GSPC",
    "DOW JONES-OTC": "^DJI",
}

QUOTE_CURRENCIES = {
    "BTC/USD-OTC": "USD",
    "ETH/USD-OTC": "USD",
    "SOL/USD-OTC": "USD",
    "XRP/USD-OTC": "USD",
    "DOGE/USD-OTC": "USD",
    "EUR/USD-OTC": "USD",
    "GBP/USD-OTC": "USD",
    "USD/JPY-OTC": "JPY",
    "AUD/USD-OTC": "USD",
    "USD/CAD-OTC": "CAD",
    "USD/CHF-OTC": "CHF",
    "EUR/GBP-OTC": "GBP",
    "EUR/JPY-OTC": "JPY",
    "GBP/JPY-OTC": "JPY",
    "AUD/JPY-OTC": "JPY",
    "GOLD/USD-OTC": "USD",
    "SILVER/USD-OTC": "USD",
    "NASDAQ-OTC": "USD",
    "S&P500-OTC": "USD",
    "DOW JONES-OTC": "USD",
}

BINANCE_URLS = (
    "https://data-api.binance.vision/api/v3/ticker/price",
    "https://api.binance.com/api/v3/ticker/price",
)

HttpGet = Callable[[str], object]


def quote_currency(symbol: str) -> str:
    return QUOTE_CURRENCIES.get(symbol, "USD")


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


def _safe_get(http_get: HttpGet, url: str) -> object | None:
    try:
        return http_get(url)
    except (urllib.error.URLError, TimeoutError, ValueError, json.JSONDecodeError, OSError):
        return None


def _fill(target: dict[str, dict], symbol: str, price: float, source: str, *, quote: str, instrument: str) -> None:
    if symbol in target or not is_valid_price(price):
        return
    cfg = ASSET_CONFIGS.get(symbol)
    precision = cfg.precision if cfg is not None else 8
    target[symbol] = {
        "price": round(float(price), precision),
        "source": source,
        "quote": quote,
        "instrument": instrument,
    }


def fetch_coingecko_usd_prices(http_get: HttpGet | None = None) -> dict[str, dict]:
    getter = http_get or _default_http_get
    mapped: dict[str, dict] = {}
    ids = ",".join(COINGECKO_IDS.values())
    raw = _safe_get(
        getter,
        f"https://api.coingecko.com/api/v3/simple/price?ids={ids}&vs_currencies=usd",
    )
    if not isinstance(raw, dict):
        return mapped
    for otc, coin_id in COINGECKO_IDS.items():
        row = raw.get(coin_id)
        price = row.get("usd") if isinstance(row, dict) else None
        if is_valid_price(price):
            _fill(
                mapped,
                otc,
                float(price),
                "coingecko_usd",
                quote="USD",
                instrument=f"{coin_id}/usd",
            )
    return mapped


def fetch_kraken_usd_prices(http_get: HttpGet | None = None) -> dict[str, dict]:
    getter = http_get or _default_http_get
    mapped: dict[str, dict] = {}
    pairs = ",".join(pair[0] for pair in KRAKEN_PAIRS.values())
    raw = _safe_get(getter, f"https://api.kraken.com/0/public/Ticker?pair={pairs}")
    if not isinstance(raw, dict):
        return mapped
    result = raw.get("result")
    if not isinstance(result, dict):
        return mapped
    for otc, aliases in KRAKEN_PAIRS.items():
        row = None
        for alias in aliases:
            if alias in result:
                row = result[alias]
                break
            for key, value in result.items():
                if alias.replace("/", "") in str(key):
                    row = value
                    break
            if row is not None:
                break
        last = row.get("c") if isinstance(row, dict) else None
        price = last[0] if isinstance(last, list) and last else None
        if is_valid_price(price):
            _fill(
                mapped,
                otc,
                float(price),
                "kraken_usd",
                quote="USD",
                instrument=f"{aliases[0]}",
            )
    return mapped


def fetch_binance_usdt_prices(http_get: HttpGet | None = None) -> dict[str, dict]:
    getter = http_get or _default_http_get
    mapped: dict[str, dict] = {}
    raw = None
    for url in BINANCE_URLS:
        raw = _safe_get(getter, url)
        if raw is not None:
            break
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
            _fill(
                mapped,
                otc,
                float(price),
                "binance_usdt",
                quote="USDT",
                instrument=binance,
            )
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


def fetch_forex_usd_prices(http_get: HttpGet | None = None) -> dict[str, dict]:
    getter = http_get or _default_http_get
    mapped: dict[str, dict] = {}
    raw = _safe_get(getter, "https://api.frankfurter.app/latest?from=USD")
    rates = raw.get("rates") if isinstance(raw, dict) else None
    if not isinstance(rates, dict):
        return mapped
    for otc, (base, quote) in FRANKFURTER_PAIRS.items():
        price = _cross_rate(rates, base, quote)
        if price is not None and is_valid_price(price):
            _fill(
                mapped,
                otc,
                price,
                "frankfurter",
                quote=quote,
                instrument=f"{base}/{quote}",
            )
    return mapped


def fetch_yahoo_seed_prices(http_get: HttpGet | None = None) -> dict[str, dict]:
    getter = http_get or _default_http_get
    mapped: dict[str, dict] = {}
    symbols = ",".join(YAHOO_METALS_INDICES.values())
    query = urllib.parse.urlencode(
        {"symbols": symbols, "range": "1d", "interval": "1d"}
    )
    raw = _safe_get(getter, f"https://query1.finance.yahoo.com/v8/finance/spark?{query}")
    if not isinstance(raw, dict):
        return mapped
    for otc, yahoo in YAHOO_METALS_INDICES.items():
        row = raw.get(yahoo)
        if not isinstance(row, dict):
            continue
        price = row.get("fulldayPrice")
        if not is_valid_price(price):
            closes = row.get("close")
            if isinstance(closes, list) and closes:
                price = closes[-1]
        if not is_valid_price(price):
            continue
        kind = "yahoo_index" if yahoo.startswith("^") else "yahoo_futures"
        _fill(
            mapped,
            otc,
            float(price),
            kind,
            quote="USD",
            instrument=yahoo,
        )
    return mapped


def fetch_paxg_gold_fallback(http_get: HttpGet | None = None) -> dict[str, dict]:
    getter = http_get or _default_http_get
    mapped: dict[str, dict] = {}
    raw = None
    for url in BINANCE_URLS:
        raw = _safe_get(getter, f"{url}?symbol=PAXGUSDT")
        if raw is not None:
            break
    price = raw.get("price") if isinstance(raw, dict) else None
    if is_valid_price(price):
        _fill(
            mapped,
            "GOLD/USD-OTC",
            float(price),
            "binance_paxg_usdt",
            quote="USDT",
            instrument="PAXGUSDT",
        )
    return mapped


def collect_reference_prices(http_get: HttpGet | None = None) -> dict[str, dict]:
    prices: dict[str, dict] = {}
    for batch in (
        fetch_coingecko_usd_prices(http_get),
        fetch_kraken_usd_prices(http_get),
        fetch_binance_usdt_prices(http_get),
        fetch_forex_usd_prices(http_get),
        fetch_yahoo_seed_prices(http_get),
        fetch_paxg_gold_fallback(http_get),
    ):
        for symbol, info in batch.items():
            prices.setdefault(symbol, info)

    report: dict[str, dict] = {}
    for symbol, cfg in ASSET_CONFIGS.items():
        if symbol in prices:
            report[symbol] = prices[symbol]
            continue
        if symbol in YAHOO_METALS_INDICES:
            reason = "No metals/index reference quote was returned"
        elif symbol in COINGECKO_IDS:
            reason = "No crypto USD or USDT reference quote was returned"
        elif symbol in FRANKFURTER_PAIRS:
            reason = "No forex reference quote was returned"
        else:
            reason = "No reference quote was returned"
        report[symbol] = {
            "price": None,
            "source": "catalog_fallback",
            "quote": quote_currency(symbol),
            "instrument": cfg.symbol,
            "reason": reason,
        }
    return report
