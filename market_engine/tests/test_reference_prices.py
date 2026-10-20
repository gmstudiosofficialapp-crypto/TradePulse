from market_engine.config.assets import ASSET_CONFIGS
from market_engine.config.settings import EngineSettings
from market_engine.services.market_runtime import MarketRuntime
from market_engine.services.reference_prices import (
    BINANCE_SYMBOLS,
    COINGECKO_IDS,
    FRANKFURTER_PAIRS,
    QUOTE_CURRENCIES,
    YAHOO_METALS_INDICES,
    collect_reference_prices,
    is_valid_price,
    normalize_binance_symbol,
    quote_currency,
)


def test_every_supported_asset_has_an_explicit_mapping() -> None:
    assert set(ASSET_CONFIGS) == set(QUOTE_CURRENCIES)
    crypto = set(COINGECKO_IDS)
    forex = set(FRANKFURTER_PAIRS)
    metals_indices = set(YAHOO_METALS_INDICES)
    assert crypto | forex | metals_indices == set(ASSET_CONFIGS)
    assert crypto == set(BINANCE_SYMBOLS)
    assert quote_currency("USD/JPY-OTC") == "JPY"
    assert quote_currency("EUR/GBP-OTC") == "GBP"
    assert quote_currency("GOLD/USD-OTC") == "USD"
    assert quote_currency("NASDAQ-OTC") == "USD"


def test_crypto_symbol_mapping_is_explicit() -> None:
    assert normalize_binance_symbol("BTC/USD-OTC") == "BTCUSDT"
    assert normalize_binance_symbol("ETH/USD-OTC") == "ETHUSDT"
    assert normalize_binance_symbol("SOL/USD-OTC") == "SOLUSDT"
    assert normalize_binance_symbol("GOLD/USD-OTC") is None


def test_invalid_and_stale_prices_are_rejected() -> None:
    assert is_valid_price(104250.12) is True
    assert is_valid_price(0) is False
    assert is_valid_price(-12) is False
    assert is_valid_price("abc") is False
    assert is_valid_price(float("nan")) is False


def _http_binance_and_frankfurter(url: str):
    if "binance" in url and "PAXGUSDT" not in url:
        return [
            {"symbol": "BTCUSDT", "price": "104250.12"},
            {"symbol": "ETHUSDT", "price": "0"},
            {"symbol": "FAKEUSDT", "price": "12"},
        ]
    if "frankfurter" in url:
        return {"rates": {"EUR": 0.92, "GBP": 0.78, "JPY": 151.2}}
    return {}


def test_collect_reference_prices_uses_provider_payloads() -> None:
    report = collect_reference_prices(_http_binance_and_frankfurter)
    assert report["BTC/USD-OTC"]["price"] == 104250.12
    assert report["BTC/USD-OTC"]["source"] == "binance_usdt"
    assert report["BTC/USD-OTC"]["quote"] == "USDT"
    assert report["ETH/USD-OTC"]["price"] is None
    assert report["EUR/USD-OTC"]["price"] == round(1 / 0.92, 5)
    assert report["EUR/USD-OTC"]["quote"] == "USD"
    assert report["USD/JPY-OTC"]["price"] == 151.2
    assert report["USD/JPY-OTC"]["quote"] == "JPY"
    assert report["GOLD/USD-OTC"]["source"] == "catalog_fallback"
    assert report["GOLD/USD-OTC"]["price"] is None
    assert set(report) == set(ASSET_CONFIGS)


def test_coingecko_usd_is_preferred_over_binance_usdt() -> None:
    def http_get(url: str):
        if "coingecko" in url:
            return {
                "bitcoin": {"usd": 81419},
                "ethereum": {"usd": 2383.83},
                "solana": {"usd": 103.98},
                "ripple": {"usd": 1.29},
                "dogecoin": {"usd": 0.078903},
            }
        if "binance" in url:
            return [{"symbol": "BTCUSDT", "price": "1"}]
        return {}

    report = collect_reference_prices(http_get)
    assert report["BTC/USD-OTC"]["price"] == 81419
    assert report["BTC/USD-OTC"]["source"] == "coingecko_usd"
    assert report["BTC/USD-OTC"]["quote"] == "USD"
    assert report["ETH/USD-OTC"]["price"] == 2383.83
    assert report["XRP/USD-OTC"]["price"] == 1.29
    assert report["DOGE/USD-OTC"]["price"] == 0.0789


def test_yahoo_seeds_metals_and_indices() -> None:
    def http_get(url: str):
        if "spark" in url:
            return {
                "GC=F": {"fulldayPrice": 4141.6},
                "SI=F": {"fulldayPrice": 57.565},
                "^IXIC": {"fulldayPrice": 26430.887},
                "^GSPC": {"close": [7690.73]},
                "^DJI": {"fulldayPrice": 51966.03},
            }
        return {}

    report = collect_reference_prices(http_get)
    assert report["GOLD/USD-OTC"]["price"] == 4141.6
    assert report["GOLD/USD-OTC"]["source"] == "yahoo_futures"
    assert report["GOLD/USD-OTC"]["instrument"] == "GC=F"
    assert report["SILVER/USD-OTC"]["price"] == 57.565
    assert report["NASDAQ-OTC"]["source"] == "yahoo_index"
    assert report["NASDAQ-OTC"]["instrument"] == "^IXIC"
    assert report["NASDAQ-OTC"]["price"] == 26430.89
    assert report["S&P500-OTC"]["price"] == 7690.73
    assert report["DOW JONES-OTC"]["price"] == 51966.03


def test_runtime_rebases_shared_streams_without_splitting_the_engine() -> None:
    runtime = MarketRuntime(
        settings=EngineSettings(history_size=3, warmup_ticks_per_minute=2),
        assets=[ASSET_CONFIGS["BTC/USD-OTC"], ASSET_CONFIGS["ETH/USD-OTC"]],
    )
    runtime.apply_reference_prices(
        {
            "BTC/USD-OTC": {"price": 104250.12, "source": "binance_usdt"},
            "ETH/USD-OTC": {"price": None, "source": "unavailable"},
        }
    )
    runtime.warmup()
    btc = runtime.quotes["BTC/USD-OTC"].price
    eth = runtime.quotes["ETH/USD-OTC"].price
    assert abs(btc - 104250.12) / 104250.12 < 0.05
    assert 2000 < eth < 5000
    again = runtime.snapshot_quote("BTC/USD-OTC")
    assert again["price_basis"] == "otc_simulated"
    assert again["simulated"] is True
    assert again["quote_currency"] == "USD"
    assert again["precision"] == 2
    assert again["reference"]["source"] == "binance_usdt"
    assert len(runtime.streams) == 2


def test_ohlc_stays_internally_consistent_after_rebase() -> None:
    runtime = MarketRuntime(
        settings=EngineSettings(history_size=5, warmup_ticks_per_minute=4),
        assets=[ASSET_CONFIGS["XRP/USD-OTC"], ASSET_CONFIGS["USD/JPY-OTC"]],
    )
    runtime.apply_reference_prices(
        {
            "XRP/USD-OTC": {"price": 1.29, "source": "coingecko_usd"},
            "USD/JPY-OTC": {"price": 158.24, "source": "frankfurter"},
        }
    )
    runtime.warmup()
    for symbol in ("XRP/USD-OTC", "USD/JPY-OTC"):
        for candle in runtime.history(symbol):
            assert candle["high"] >= max(candle["open"], candle["close"])
            assert candle["low"] <= min(candle["open"], candle["close"])
            assert candle["high"] >= candle["low"]
        quote = runtime.snapshot_quote(symbol)
        assert quote["simulated"] is True
        assert quote["price_basis"] == "otc_simulated"
