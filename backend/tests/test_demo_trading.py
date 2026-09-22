from datetime import datetime, timedelta, timezone

import pytest

from app.core.safety import LiveTradingDisabledError, execute_live_trade
from app.core.trading_settings import ASSET_PAYOUT_RATES
from app.services.demo_trading import DemoTradingEngine


def test_demo_balance_default() -> None:
    engine = DemoTradingEngine()
    assert engine.balance("alice") == 10000.0


def test_insufficient_balance() -> None:
    engine = DemoTradingEngine()
    engine.open_trade("alice", "BTC/USD-OTC", "BUY", 10000, 100)
    with pytest.raises(ValueError, match="Insufficient"):
        engine.open_trade("alice", "BTC/USD-OTC", "BUY", 1, 100)


def test_stake_limits_per_signal() -> None:
    engine = DemoTradingEngine()
    with pytest.raises(ValueError, match="Invalid stake"):
        engine.open_trade("alice", "BTC/USD-OTC", "BUY", 0.99, 100)
    with pytest.raises(ValueError, match="Invalid stake"):
        engine.open_trade("alice", "BTC/USD-OTC", "BUY", 10000.01, 100)
    trade = engine.open_trade("alice", "BTC/USD-OTC", "BUY", 1, 100)
    assert trade["stake"] == 1
    other = engine.open_trade("bob", "ETH/USD-OTC", "SELL", 10000, 200)
    assert other["stake"] == 10000


def test_ten_open_trades_total() -> None:
    engine = DemoTradingEngine()
    for index in range(10):
        engine.open_trade("alice", "BTC/USD-OTC", "BUY", 1, 100 + index)
    with pytest.raises(ValueError, match="Maximum 10 active trades reached"):
        engine.open_trade("alice", "BTC/USD-OTC", "SELL", 1, 120)
    with pytest.raises(ValueError, match="Maximum 10 active trades reached"):
        engine.open_trade("alice", "ETH/USD-OTC", "BUY", 1, 200)
    open_btc = [t for t in engine.trades.list_for_user("alice") if t["result"] is None]
    engine.settle(open_btc[0]["trade_id"], open_btc[0]["entry_price"] + 1)
    extra = engine.open_trade("alice", "ETH/USD-OTC", "SELL", 1, 130)
    assert extra["direction"] == "SELL"


def test_demo_credit_is_spendable() -> None:
    engine = DemoTradingEngine()
    assert engine.credit_demo("alice", 5000) == 15000.0
    trade = engine.open_trade("alice", "BTC/USD-OTC", "BUY", 10000, 100)
    assert trade["stake"] == 10000
    assert engine.balance("alice") == 5000.0
    engine.open_trade("alice", "BTC/USD-OTC", "SELL", 5000, 100)
    assert engine.balance("alice") == 0.0


def test_buy_win() -> None:
    engine = DemoTradingEngine()
    trade = engine.open_trade("alice", "BTC/USD-OTC", "BUY", 10, 100)
    settled = engine.settle(trade["trade_id"], 110)
    assert settled["result"] == "WIN"
    assert settled["profit_loss"] == 9.2
    assert engine.balance("alice") == 10009.2


def test_buy_loss() -> None:
    engine = DemoTradingEngine()
    trade = engine.open_trade("alice", "BTC/USD-OTC", "BUY", 10, 100)
    settled = engine.settle(trade["trade_id"], 90)
    assert settled["result"] == "LOSS"
    assert engine.balance("alice") == 9990.0


def test_sell_win() -> None:
    engine = DemoTradingEngine()
    trade = engine.open_trade("bob", "ETH/USD-OTC", "SELL", 10, 100)
    settled = engine.settle(trade["trade_id"], 90)
    assert settled["result"] == "WIN"


def test_sell_loss() -> None:
    engine = DemoTradingEngine()
    trade = engine.open_trade("bob", "ETH/USD-OTC", "SELL", 10, 100)
    settled = engine.settle(trade["trade_id"], 110)
    assert settled["result"] == "LOSS"


def test_draw() -> None:
    engine = DemoTradingEngine()
    trade = engine.open_trade("cara", "SOL/USD-OTC", "BUY", 10, 100)
    settled = engine.settle(trade["trade_id"], 100)
    assert settled["result"] == "DRAW"
    assert engine.balance("cara") == 10000.0


def test_asset_payout_tiers() -> None:
    engine = DemoTradingEngine()
    btc = engine.open_trade("tier", "BTC/USD-OTC", "BUY", 10, 100)
    xrp = engine.open_trade("tier", "XRP/USD-OTC", "BUY", 10, 1)
    doge = engine.open_trade("tier", "DOGE/USD-OTC", "BUY", 10, 1)
    dow = engine.open_trade("tier", "DOW JONES-OTC", "BUY", 10, 100)
    assert btc["payout_rate"] == 0.92
    assert xrp["payout_rate"] == 0.90
    assert doge["payout_rate"] == 0.85
    assert dow["payout_rate"] == 0.80
    assert len({*ASSET_PAYOUT_RATES.values()}) == 4
    assert sum(1 for rate in ASSET_PAYOUT_RATES.values() if rate == 0.92) == 10
    assert sum(1 for rate in ASSET_PAYOUT_RATES.values() if rate == 0.90) == 2
    assert sum(1 for rate in ASSET_PAYOUT_RATES.values() if rate == 0.85) == 5
    assert sum(1 for rate in ASSET_PAYOUT_RATES.values() if rate == 0.80) == 3
    assert len(ASSET_PAYOUT_RATES) == 20


def test_payout_calculation() -> None:
    engine = DemoTradingEngine()
    trade = engine.open_trade("dave", "BTC/USD-OTC", "BUY", 20, 50)
    settled = engine.settle(trade["trade_id"], 51)
    assert settled["payout_rate"] == 0.92
    assert settled["profit_loss"] == 18.4


def test_trade_settlement_and_history() -> None:
    engine = DemoTradingEngine()
    trade = engine.open_trade(
        "erin",
        "BTC/USD-OTC",
        "BUY",
        10,
        100,
        now=datetime(2026, 1, 1, tzinfo=timezone.utc),
    )
    engine.settle(trade["trade_id"], 101)
    history = engine.trades.list_for_user("erin")
    assert len(history) == 1
    assert history[0]["result"] == "WIN"
    stats = engine.statistics("erin")
    assert stats["wins"] == 1
    assert stats["total_trades"] == 1


def test_history_keeps_the_latest_100_trades() -> None:
    engine = DemoTradingEngine()
    start = datetime(2026, 1, 1, tzinfo=timezone.utc)
    kept = []
    for index in range(101):
        trade = engine.open_trade(
            "alice",
            "BTC/USD-OTC",
            "BUY",
            1,
            100,
            now=start + timedelta(seconds=index),
            expiry_seconds=5,
        )
        engine.settle(trade["trade_id"], 99)
        kept.append(trade["trade_id"])
    other = engine.open_trade(
        "bob",
        "ETH/USD-OTC",
        "SELL",
        1,
        50,
        now=start,
        expiry_seconds=5,
    )
    rows = engine.trades.list_for_user("alice")
    ids = {row["trade_id"] for row in rows}
    assert len(rows) == 100
    assert kept[0] not in ids
    assert kept[-1] in ids
    assert engine.trades.get(other["trade_id"])["user_id"] == "bob"


def test_hot_settle_updates_balance_before_persist() -> None:
    accounts = _TrackingAccounts()
    ledger = _DeferredLedger(accounts)
    engine = DemoTradingEngine(
        accounts=accounts,
        trades=_LooseTrades(),
        ledger=ledger,
    )
    trade = engine.open_trade("alice", "BTC/USD-OTC", "BUY", 10, 100)
    settled = engine.settle(trade["trade_id"], 110)
    assert settled["result"] == "WIN"
    assert engine.balance("alice") == 10009.2
    again = engine.settle(trade["trade_id"], 80)
    assert again["result"] == "WIN"
    assert engine.balance("alice") == 10009.2


class _TrackingAccounts:
    def __init__(self) -> None:
        self.amount = 10000.0

    def get_balance(self, user_id: str) -> float:
        return self.amount

    def set_balance(self, user_id: str, amount: float) -> None:
        self.amount = amount


class _LooseTrades:
    def __init__(self) -> None:
        self.rows: dict[str, dict] = {}

    def list_for_user(self, user_id: str) -> list[dict]:
        return [dict(row) for row in self.rows.values() if row.get("user_id") == user_id]

    def all_open(self) -> list[dict]:
        return []

    def get(self, trade_id: str) -> dict | None:
        row = self.rows.get(trade_id)
        return dict(row) if row is not None else None

    def delete(self, trade_id: str) -> None:
        self.rows.pop(trade_id, None)

    def save(self, trade: dict) -> None:
        self.rows[trade["trade_id"]] = dict(trade)


class _DeferredLedger:
    defer_writes = True

    def __init__(self, accounts: _TrackingAccounts) -> None:
        self.accounts = accounts

    def commit_open(self, **kwargs) -> dict:
        self.accounts.amount = round(self.accounts.amount - kwargs["stake"], 2)
        return dict(kwargs["trade"])

    def commit_settle(self, trade_id: str, expiry_price: float, apply) -> dict:
        return {"trade_id": trade_id}


def test_duplicate_settlement_protection() -> None:
    engine = DemoTradingEngine()
    trade = engine.open_trade("finn", "BTC/USD-OTC", "BUY", 10, 100)
    first = engine.settle(trade["trade_id"], 110)
    second = engine.settle(trade["trade_id"], 80)
    assert first["result"] == second["result"] == "WIN"
    assert engine.balance("finn") == 10009.2


def test_multiple_users_and_assets() -> None:
    engine = DemoTradingEngine()
    a = engine.open_trade("u1", "BTC/USD-OTC", "BUY", 10, 100)
    b = engine.open_trade("u2", "EUR/USD-OTC", "SELL", 25, 1.1)
    engine.settle(a["trade_id"], 101)
    engine.settle(b["trade_id"], 1.2)
    assert engine.balance("u1") == 10009.2
    assert engine.balance("u2") == 9975.0
    assert engine.statistics("u1")["wins"] == 1
    assert engine.statistics("u2")["losses"] == 1


def test_custom_expiry_durations() -> None:
    engine = DemoTradingEngine()
    now = datetime(2026, 1, 1, tzinfo=timezone.utc)
    for seconds in (5, 15, 30, 60, 300, 900):
        trade = engine.open_trade(
            "exp",
            "BTC/USD-OTC",
            "BUY",
            10,
            100,
            now=now,
            expiry_seconds=seconds,
        )
        assert trade["expiry_seconds"] == seconds
        assert datetime.fromisoformat(trade["expiry_time"]) == now + timedelta(
            seconds=seconds
        )
    with pytest.raises(ValueError, match="Invalid expiry"):
        engine.open_trade("exp", "BTC/USD-OTC", "BUY", 10, 100, expiry_seconds=7)


def test_live_trading_rejection() -> None:
    engine = DemoTradingEngine()
    with pytest.raises(LiveTradingDisabledError):
        execute_live_trade()
    with pytest.raises(LiveTradingDisabledError):
        engine.open_trade("alice", "BTC/USD-OTC", "BUY", 10, 100, live=True)
