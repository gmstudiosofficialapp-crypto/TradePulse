"""Two-user concurrent isolation: account state private, market data shared."""

from __future__ import annotations

import asyncio
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone

from fastapi.testclient import TestClient

from app.core.runtime import get_coordinator, get_trading
from app.main import create_app
from market_engine.config.assets import ASSET_CONFIGS
from market_engine.config.settings import EngineSettings
from market_engine.services.market_runtime import MarketRuntime

ASSET = "BTC/USD-OTC"
USER_A = "user-a|a@tradepulse.test"
USER_B = "user-b|b@tradepulse.test"
AUTH_A = {"Authorization": f"Bearer {USER_A}"}
AUTH_B = {"Authorization": f"Bearer {USER_B}"}


def _client() -> TestClient:
    runtime = MarketRuntime(
        settings=EngineSettings(history_size=8, warmup_ticks_per_minute=2),
        assets=[ASSET_CONFIGS[ASSET]],
    )
    runtime.warmup()
    return TestClient(create_app(runtime=runtime, auto_start=False))


def _settle_due(price: float) -> None:
    asyncio.run(
        get_coordinator()._settle_due(
            datetime.now(timezone.utc) + timedelta(minutes=1),
            {ASSET: price},
        )
    )


def _ids(trades: list[dict]) -> set[str]:
    return {item["trade_id"] for item in trades}


def _open(client: TestClient, headers: dict, direction: str, stake: float) -> dict:
    response = client.post(
        "/api/demo/trades",
        headers=headers,
        json={
            "asset": ASSET,
            "direction": direction,
            "stake": stake,
            "expiry_seconds": 5,
        },
    )
    assert response.status_code == 200, response.text
    return response.json()


def _drain_until_pong(ws) -> list[dict]:
    ws.send_json({"type": "ping"})
    collected: list[dict] = []
    for _ in range(40):
        message = ws.receive_json()
        if message.get("type") == "pong":
            return collected
        collected.append(message)
    raise AssertionError(f"pong not received; saw {collected}")


def _subscribe_market(ws, token: str | None = None) -> None:
    assert ws.receive_json()["type"] == "status"
    if token:
        ws.send_json({"type": "identify", "token": token})
        identified = ws.receive_json()
        assert identified["type"] == "identified"
        assert identified["user_id"] == token.split("|", 1)[0]
    ws.send_json({"type": "subscribe", "asset": ASSET})
    assert ws.receive_json()["type"] == "subscribed"
    quote = ws.receive_json()
    assert quote["type"] == "quote"


def test_two_user_http_and_settlement_isolation() -> None:
    with _client() as client:
        me_a = client.post("/api/me", headers=AUTH_A).json()
        me_b = client.post("/api/me", headers=AUTH_B).json()
        assert me_a["user"]["uid"] == "user-a"
        assert me_b["user"]["uid"] == "user-b"
        assert me_a["balance"] == me_b["balance"] == 10000.0

        with ThreadPoolExecutor(max_workers=2) as pool:
            future_a = pool.submit(_open, client, AUTH_A, "BUY", 10)
            future_b = pool.submit(_open, client, AUTH_B, "SELL", 25)
            trade_a = future_a.result()
            trade_b = future_b.result()

        assert trade_a["user_id"] == "user-a"
        assert trade_b["user_id"] == "user-b"
        assert trade_a["trade_id"] != trade_b["trade_id"]

        bal_a = client.get("/api/demo/balance", headers=AUTH_A).json()
        bal_b = client.get("/api/demo/balance", headers=AUTH_B).json()
        assert bal_a["balance"] == 9990.0
        assert bal_b["balance"] == 9975.0

        open_a = client.get("/api/demo/trades", headers=AUTH_A).json()["trades"]
        open_b = client.get("/api/demo/trades", headers=AUTH_B).json()["trades"]
        assert _ids(open_a) == {trade_a["trade_id"]}
        assert _ids(open_b) == {trade_b["trade_id"]}
        assert all(item["user_id"] == "user-a" for item in open_a)
        assert all(item["user_id"] == "user-b" for item in open_b)

        quotes_a = client.get("/api/market/quotes").json()
        quotes_b = client.get("/api/market/quotes").json()
        assert quotes_a == quotes_b
        candles_a = client.get("/api/market/candles", params={"asset": ASSET, "limit": "20"}).json()
        candles_b = client.get("/api/market/candles", params={"asset": ASSET, "limit": "20"}).json()
        assert candles_a == candles_b
        status_a = client.get("/api/market/status").json()
        status_b = client.get("/api/market/status").json()
        assert status_a["state"] == status_b["state"]

        trading = get_trading()
        trading.settle(trade_a["trade_id"], trade_a["entry_price"] + 15)
        trading.settle(trade_b["trade_id"], trade_b["entry_price"] + 15)

        after_a = client.get("/api/demo/trades", headers=AUTH_A).json()["trades"]
        after_b = client.get("/api/demo/trades", headers=AUTH_B).json()["trades"]
        settled_a = next(item for item in after_a if item["trade_id"] == trade_a["trade_id"])
        settled_b = next(item for item in after_b if item["trade_id"] == trade_b["trade_id"])
        assert settled_a["result"] == "WIN"
        assert settled_b["result"] == "LOSS"
        assert settled_a["user_id"] == "user-a"
        assert settled_b["user_id"] == "user-b"
        assert trade_a["trade_id"] not in _ids(after_b)
        assert trade_b["trade_id"] not in _ids(after_a)

        win_credit = round(10 + 10 * settled_a["payout_rate"], 2)
        assert client.get("/api/demo/balance", headers=AUTH_A).json()["balance"] == round(
            9990.0 + win_credit, 2
        )
        assert client.get("/api/demo/balance", headers=AUTH_B).json()["balance"] == 9975.0

        stats_a = client.get("/api/demo/statistics", headers=AUTH_A).json()
        stats_b = client.get("/api/demo/statistics", headers=AUTH_B).json()
        assert stats_a["wins"] == 1
        assert stats_a["losses"] == 0
        assert stats_b["wins"] == 0
        assert stats_b["losses"] == 1
        assert stats_a["total_profit_loss"] != stats_b["total_profit_loss"]

        tx_a = client.get("/api/demo/transactions", headers=AUTH_A).json()["transactions"]
        tx_b = client.get("/api/demo/transactions", headers=AUTH_B).json()["transactions"]
        assert all(item["user_id"] == "user-a" for item in tx_a)
        assert all(item["user_id"] == "user-b" for item in tx_b)
        assert {item["referenceId"] for item in tx_a if item.get("referenceId")} <= {
            trade_a["trade_id"]
        } | {None}
        assert trade_a["trade_id"] not in {item.get("referenceId") for item in tx_b}
        assert trade_b["trade_id"] not in {item.get("referenceId") for item in tx_a}

        engine = get_trading()
        assert all(item["user_id"] == "user-a" for item in engine.listed_trades("user-a"))
        assert all(item["user_id"] == "user-b" for item in engine.listed_trades("user-b"))


def test_websocket_account_events_do_not_cross_users() -> None:
    with _client() as client:
        with client.websocket_connect("/ws/market") as ws_a, client.websocket_connect(
            "/ws/market"
        ) as ws_b, client.websocket_connect("/ws/market") as public:
            _subscribe_market(ws_a, USER_A)
            _subscribe_market(ws_b, USER_B)
            _subscribe_market(public)

            trade_a = _open(client, AUTH_A, "BUY", 10)
            seen_a = _drain_until_pong(ws_a)
            seen_b = _drain_until_pong(ws_b)
            seen_public = _drain_until_pong(public)

            types_a = {item.get("type") for item in seen_a}
            assert "trade_opened" in types_a
            assert "balance_updated" in types_a
            assert all(
                item.get("user_id") == "user-a"
                or (item.get("trade") or {}).get("user_id") == "user-a"
                for item in seen_a
                if item.get("type") in {"trade_opened", "balance_updated"}
            )
            assert all(
                item.get("type") not in {"trade_opened", "trade_result", "balance_updated"}
                for item in seen_b
            )
            assert all(
                item.get("type") not in {"trade_opened", "trade_result", "balance_updated"}
                for item in seen_public
            )

            trade_b = _open(client, AUTH_B, "SELL", 15)
            seen_a = _drain_until_pong(ws_a)
            seen_b = _drain_until_pong(ws_b)
            assert all(
                item.get("type") not in {"trade_opened", "balance_updated"} for item in seen_a
            )
            assert any(item.get("type") == "trade_opened" for item in seen_b)
            assert any(
                (item.get("trade") or {}).get("trade_id") == trade_b["trade_id"] for item in seen_b
            )
            assert all(
                (item.get("trade") or {}).get("trade_id") != trade_a["trade_id"] for item in seen_b
            )

            trading = get_trading()
            settled_a = trading.settle(trade_a["trade_id"], trade_a["entry_price"] + 20)
            settled_b = trading.settle(trade_b["trade_id"], trade_b["entry_price"] + 20)
            asyncio.run(
                get_coordinator()._emit(
                    {
                        "type": "trade_result",
                        "user_id": settled_a["user_id"],
                        "asset": ASSET,
                        "trade": settled_a,
                    }
                )
            )
            asyncio.run(
                get_coordinator()._emit(
                    {
                        "type": "trade_result",
                        "user_id": settled_b["user_id"],
                        "asset": ASSET,
                        "trade": settled_b,
                    }
                )
            )
            seen_a = _drain_until_pong(ws_a)
            seen_b = _drain_until_pong(ws_b)
            assert any(item.get("type") == "trade_result" for item in seen_a)
            assert any(item.get("type") == "trade_result" for item in seen_b)
            assert all(
                (item.get("trade") or {}).get("user_id") == "user-a"
                for item in seen_a
                if item.get("type") == "trade_result"
            )
            assert all(
                (item.get("trade") or {}).get("user_id") == "user-b"
                for item in seen_b
                if item.get("type") == "trade_result"
            )

            ws_a.send_json({"type": "subscribe", "asset": ASSET})
            ws_b.send_json({"type": "subscribe", "asset": ASSET})
            resub_a = ws_a.receive_json()
            resub_b = ws_b.receive_json()
            assert resub_a["type"] == resub_b["type"] == "subscribed"
            q_a = ws_a.receive_json()
            q_b = ws_b.receive_json()
            assert q_a["type"] == q_b["type"] == "quote"
            assert q_a["data"]["price"] == q_b["data"]["price"]
            assert q_a["data"]["timestamp"] == q_b["data"]["timestamp"]


def test_identify_rejects_client_supplied_user_id() -> None:
    with _client() as client:
        with client.websocket_connect("/ws/market") as ws:
            assert ws.receive_json()["type"] == "status"
            ws.send_json({"type": "identify", "user_id": "user-a"})
            error = ws.receive_json()
            assert error["type"] == "error"
            assert "token" in error["message"].lower()
            ws.send_json({"type": "identify", "token": "invalid"})
            denied = ws.receive_json()
            assert denied["type"] == "error"


def test_http_ignores_body_user_id() -> None:
    with _client() as client:
        opened = client.post(
            "/api/demo/trades",
            headers=AUTH_A,
            json={
                "asset": ASSET,
                "direction": "BUY",
                "stake": 10,
                "user_id": "user-b",
            },
        )
        assert opened.status_code == 200
        assert opened.json()["user_id"] == "user-a"
        other = client.get("/api/demo/trades", headers=AUTH_B).json()["trades"]
        assert other == []
