from market_engine.config.assets import ASSET_CONFIGS
from market_engine.config.settings import EngineSettings
from market_engine.services.market_runtime import MarketRuntime
from market_engine.services.reference_prices import (
    collect_reference_prices,
    is_valid_price,
    normalize_binance_symbol,
)


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


def test_collect_reference_prices_uses_provider_payloads() -> None:
    def http_get(url: str):
        if "binance" in url:
            return [
                {"symbol": "BTCUSDT", "price": "104250.12"},
                {"symbol": "ETHUSDT", "price": "0"},
                {"symbol": "FAKEUSDT", "price": "12"},
            ]
        return {"rates": {"EUR": 0.92, "GBP": 0.78, "JPY": 151.2}}

    report = collect_reference_prices(http_get)
    assert report["BTC/USD-OTC"]["price"] == 104250.12
    assert report["BTC/USD-OTC"]["source"] == "binance"
    assert report["ETH/USD-OTC"]["price"] is None
    assert report["EUR/USD-OTC"]["price"] == 1 / 0.92
    assert report["USD/JPY-OTC"]["price"] == 151.2
    assert report["GOLD/USD-OTC"]["source"] == "catalog_fallback"
    assert report["GOLD/USD-OTC"]["price"] is None


def test_runtime_rebases_shared_streams_without_splitting_the_engine() -> None:
    runtime = MarketRuntime(
        settings=EngineSettings(history_size=3, warmup_ticks_per_minute=2),
        assets=[ASSET_CONFIGS["BTC/USD-OTC"], ASSET_CONFIGS["ETH/USD-OTC"]],
    )
    runtime.apply_reference_prices(
        {
            "BTC/USD-OTC": {"price": 104250.12, "source": "binance"},
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
    assert again["reference"]["source"] == "binance"
    assert len(runtime.streams) == 2
