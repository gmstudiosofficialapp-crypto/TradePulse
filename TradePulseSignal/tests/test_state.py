from app.client import TradePulseSignalClient
from app.state import BtcFutureState


def _candle(minute: str, role: str, close: float = 100.0) -> dict:
    start = f"2026-09-21T16:{minute}:00+00:00"
    end_minute = f"{int(minute) + 1:02d}"
    return {
        "id": f"BTC/USD-OTC|1m|{start}",
        "asset": "BTC/USD-OTC",
        "timeframe": "1m",
        "role": role,
        "candle_start_time": start,
        "candle_end_time": f"2026-09-21T16:{end_minute}:00+00:00",
        "open": 99.0,
        "high": 101.0,
        "low": 98.0,
        "close": close,
        "direction": "UP" if close > 99 else "FLAT",
        "volume": 150,
        "closed": role != "LIVE",
        "precomputed": role != "LIVE",
        "simulated": True,
    }


def _envelope(kind: str, sequence: int, live_min: str, futures: list[str]) -> dict:
    return {
        "schema_version": 1,
        "type": kind,
        "asset": "BTC/USD-OTC",
        "timeframe": "1m",
        "timezone": "UTC",
        "sequence": sequence,
        "generated_at": f"2026-09-21T16:{live_min}:20+00:00",
        "live": _candle(live_min, "LIVE"),
        "futures": [
            _candle(futures[0], "FUTURE_1"),
            _candle(futures[1], "FUTURE_2"),
            _candle(futures[2], "FUTURE_3"),
        ],
        "future_count": 3,
        "rolling": True,
    }


def test_snapshot_then_roll_promotes_and_appends() -> None:
    state = BtcFutureState()
    assert state.apply(_envelope("snapshot", 1, "09", ["10", "11", "12"]))
    assert state.live["candle_start_time"].startswith("2026-09-21T16:09:00")
    roll = _envelope("roll", 2, "10", ["11", "12", "13"])
    roll["promoted_live_id"] = roll["live"]["id"]
    roll["new_future_id"] = roll["futures"][2]["id"]
    assert state.apply(roll)
    assert state.live["id"].endswith("16:10:00+00:00")
    assert state.futures[2]["id"].endswith("16:13:00+00:00")
    assert state.last_event == "roll"


def test_consecutive_rolls() -> None:
    state = BtcFutureState()
    state.apply(_envelope("snapshot", 1, "09", ["10", "11", "12"]))
    assert state.apply(_envelope("roll", 2, "10", ["11", "12", "13"]))
    assert state.apply(_envelope("roll", 3, "11", ["12", "13", "14"]))
    assert state.live["id"].endswith("16:11:00+00:00")
    assert [item["candle_start_time"][14:16] for item in state.futures] == ["12", "13", "14"]


def test_stale_and_malformed_rejected() -> None:
    state = BtcFutureState()
    assert state.apply(_envelope("snapshot", 5, "09", ["10", "11", "12"]))
    assert not state.apply(_envelope("live_update", 4, "09", ["10", "11", "12"]))
    assert state.last_error == "stale_sequence"
    assert not state.apply({"type": "roll", "futures": []})
    assert state.last_error == "invalid_envelope"
    assert state.live["id"].endswith("16:09:00+00:00")
    assert state.needs_resync() is False
    state.apply({"bad": True})
    state.apply({"bad": True})
    state.apply({"bad": True})
    assert state.needs_resync() is True


def test_reconnect_helpers() -> None:
    client = TradePulseSignalClient("http://example.test", "token")
    client.state.apply(_envelope("snapshot", 3, "09", ["10", "11", "12"]))
    later = _envelope("snapshot", 9, "11", ["12", "13", "14"])
    assert client.state.apply(later, allow_snapshot_reset=True)
    assert client.state.live["id"].endswith("16:11:00+00:00")
    assert client.ws_url() == "ws://example.test/ws/signal-btc-future"
    assert client.headers()["Authorization"] == "Bearer token"
    assert client.reconnect_delay(0) == 1.0
    assert client.reconnect_delay(9) == 15.0
