from __future__ import annotations

from copy import deepcopy
from datetime import datetime, timedelta, timezone
from random import Random

from market_engine.config.assets import ASSET_CONFIGS
from market_engine.config.settings import EngineSettings
from market_engine.services.btc_future_book import (
    BTC_SYMBOL,
    BtcFutureBook,
    remaining_ticks,
    ticks_in_minute,
)
from market_engine.services.market_runtime import AssetStream, MarketRuntime


def _ohlc(item) -> tuple[float, float, float, float]:
    return (item.open, item.high, item.low, item.close)


def _feed(stream: AssetStream, stamps: list[datetime]):
    closed = None
    current = None
    for stamp in stamps:
        tick = stream.ticks.next_tick(stamp)
        closed, current = stream.candles.apply_tick(tick)
    return closed, current


def _btc_stream(seed: int = 99) -> AssetStream:
    return AssetStream(ASSET_CONFIGS[BTC_SYMBOL], Random(seed))


def test_clone_does_not_mutate_live_rng() -> None:
    stream = _btc_stream()
    live_open = datetime(2026, 9, 21, 16, 9, tzinfo=timezone.utc)
    interval = stream.config.tick_interval_ms
    _feed(stream, ticks_in_minute(live_open, interval)[:40])
    rng_before = stream.ticks.generator.rng.getstate()
    state_before = deepcopy(stream.ticks.generator.state)
    book = BtcFutureBook()
    book.rebuild(stream, live_open + timedelta(seconds=16))
    assert stream.ticks.generator.rng.getstate() == rng_before
    assert stream.ticks.generator.state == state_before
    assert len(book.futures) == 3


def test_live_409_precomputes_410_411_412() -> None:
    stream = _btc_stream(7)
    live_open = datetime(2026, 9, 21, 16, 9, tzinfo=timezone.utc)
    interval = stream.config.tick_interval_ms
    _feed(stream, ticks_in_minute(live_open, interval)[:25])
    book = BtcFutureBook()
    book.sync(stream, live_open + timedelta(seconds=10))
    assert book.live_open == live_open
    assert [item.open_time for item in book.futures] == [
        live_open + timedelta(minutes=1),
        live_open + timedelta(minutes=2),
        live_open + timedelta(minutes=3),
    ]
    payload = book.snapshot(stream.candles.current)
    assert payload["future_count"] == 3
    assert payload["live"]["candle_start_time"].startswith("2026-09-21T16:09:00")
    assert [row["direction"] in {"UP", "DOWN", "FLAT"} for row in payload["futures"]]


def test_precomputed_matches_live_engine_path() -> None:
    stream = _btc_stream(123)
    live_open = datetime(2026, 9, 21, 16, 9, tzinfo=timezone.utc)
    interval = stream.config.tick_interval_ms
    _feed(stream, ticks_in_minute(live_open, interval)[:40])
    book = BtcFutureBook()
    book.rebuild(stream, live_open)
    expected = [_ohlc(item) for item in book.futures]
    rng_after_rebuild = stream.ticks.generator.rng.getstate()

    _feed(stream, remaining_ticks(stream.candles.current, interval))
    actual = []
    for offset in (1, 2, 3):
        open_time = live_open + timedelta(minutes=offset)
        _closed, current = _feed(stream, ticks_in_minute(open_time, interval))
        actual.append(_ohlc(current))
    assert actual == expected
    assert stream.ticks.generator.rng.getstate() != rng_after_rebuild


def test_roll_promotes_410_and_appends_413() -> None:
    stream = _btc_stream(5)
    live_open = datetime(2026, 9, 21, 16, 9, tzinfo=timezone.utc)
    interval = stream.config.tick_interval_ms
    _feed(stream, ticks_in_minute(live_open, interval)[:30])
    book = BtcFutureBook()
    book.sync(stream, live_open)
    first_wave = [_ohlc(item) for item in book.futures]
    kept_410 = first_wave[0]
    kept_411 = first_wave[1]
    kept_412 = first_wave[2]

    _feed(stream, remaining_ticks(stream.candles.current, interval))
    closed, _current = _feed(
        stream, [live_open + timedelta(minutes=1)]
    )
    assert closed is not None
    assert closed.open_time == live_open
    book.sync(stream, live_open + timedelta(minutes=1), closed)

    assert book.live_open == live_open + timedelta(minutes=1)
    assert [item.open_time for item in book.futures] == [
        live_open + timedelta(minutes=2),
        live_open + timedelta(minutes=3),
        live_open + timedelta(minutes=4),
    ]
    assert _ohlc(book.futures[0]) == kept_411
    assert _ohlc(book.futures[1]) == kept_412
    assert book.futures[2].open_time == live_open + timedelta(minutes=4)

    rest_410 = ticks_in_minute(live_open + timedelta(minutes=1), interval)[1:]
    _closed, live_410 = _feed(stream, rest_410)
    assert _ohlc(live_410) == kept_410


def test_consecutive_minute_rolls() -> None:
    stream = _btc_stream(42)
    live_open = datetime(2026, 9, 21, 16, 9, tzinfo=timezone.utc)
    interval = stream.config.tick_interval_ms
    _feed(stream, ticks_in_minute(live_open, interval)[:10])
    book = BtcFutureBook()
    book.sync(stream, live_open)
    _feed(stream, remaining_ticks(stream.candles.current, interval))

    for minute in range(4):
        open_time = live_open + timedelta(minutes=minute)
        next_open = open_time + timedelta(minutes=1)
        if minute > 0:
            rest = ticks_in_minute(open_time, interval)[1:]
            _feed(stream, rest)
        closed, current = _feed(stream, [next_open])
        book.sync(stream, next_open, closed)
        assert current.open_time == next_open
        assert book.live_open == next_open
        assert len(book.futures) == 3
        assert [item.open_time for item in book.futures] == [
            next_open + timedelta(minutes=1),
            next_open + timedelta(minutes=2),
            next_open + timedelta(minutes=3),
        ]


def test_runtime_skips_full_rebuild_when_queue_valid() -> None:
    runtime = MarketRuntime(
        settings=EngineSettings(history_size=2, warmup_ticks_per_minute=2),
        assets=[ASSET_CONFIGS[BTC_SYMBOL]],
    )
    now = datetime(2026, 9, 21, 16, 9, 20, tzinfo=timezone.utc)
    runtime.warmup(now)
    first = [item.open_time for item in runtime.btc_future_book.futures]
    runtime.step(now + timedelta(seconds=1))
    second = [item.open_time for item in runtime.btc_future_book.futures]
    assert first == second
    assert first == [
        datetime(2026, 9, 21, 16, 10, tzinfo=timezone.utc),
        datetime(2026, 9, 21, 16, 11, tzinfo=timezone.utc),
        datetime(2026, 9, 21, 16, 12, tzinfo=timezone.utc),
    ]
    runtime.step(datetime(2026, 9, 21, 16, 10, tzinfo=timezone.utc))
    rolled = [item.open_time for item in runtime.btc_future_book.futures]
    assert rolled == [
        datetime(2026, 9, 21, 16, 11, tzinfo=timezone.utc),
        datetime(2026, 9, 21, 16, 12, tzinfo=timezone.utc),
        datetime(2026, 9, 21, 16, 13, tzinfo=timezone.utc),
    ]
    live = runtime.open_candles[BTC_SYMBOL]
    assert live.open_time == datetime(2026, 9, 21, 16, 10, tzinfo=timezone.utc)


def _direction_of(candle) -> str:
    if candle.close > candle.open:
        return "UP"
    if candle.close < candle.open:
        return "DOWN"
    return "FLAT"


def test_jittered_live_loop_matches_precomputed_futures() -> None:

    runtime = MarketRuntime(
        settings=EngineSettings(history_size=2, warmup_ticks_per_minute=2),
        assets=[ASSET_CONFIGS[BTC_SYMBOL]],
    )
    live_open = datetime(2026, 9, 21, 16, 9, tzinfo=timezone.utc)
    runtime.warmup(live_open + timedelta(seconds=20))
    predicted = {
        item.open_time: item for item in runtime.btc_future_book.futures
    }
    assert list(predicted) == [
        live_open + timedelta(minutes=1),
        live_open + timedelta(minutes=2),
        live_open + timedelta(minutes=3),
    ]
    jitter = Random(20260921)
    now = live_open + timedelta(seconds=20)
    matched: list[datetime] = []
    deadline = live_open + timedelta(minutes=5)
    while now < deadline:
        now += timedelta(milliseconds=jitter.choice([90, 240, 400, 680, 950, 1300]))
        for event in runtime.step(now):
            closed = event.closed
            if closed is None:
                continue
            for item in runtime.btc_future_book.futures:
                predicted.setdefault(item.open_time, item)
            expected = predicted.get(closed.open_time)
            if expected is None:
                continue
            assert closed.open == expected.open
            assert closed.high == expected.high
            assert closed.low == expected.low
            assert closed.close == expected.close
            assert _direction_of(closed) == expected.direction
            assert int(closed.volume) == expected.volume
            matched.append(closed.open_time)
    assert matched[:3] == [
        live_open + timedelta(minutes=1),
        live_open + timedelta(minutes=2),
        live_open + timedelta(minutes=3),
    ]
    assert live_open + timedelta(minutes=4) in matched
    live = runtime.open_candles[BTC_SYMBOL]
    assert live.open_time >= live_open + timedelta(minutes=4)


def test_irregular_gaps_still_emit_canonical_tick_count() -> None:
    from market_engine.services.btc_future_book import due_live_stamps, ticks_per_minute

    stream = _btc_stream(3)
    live_open = datetime(2026, 9, 21, 16, 9, tzinfo=timezone.utc)
    interval = stream.config.tick_interval_ms
    _feed(stream, ticks_in_minute(live_open, interval)[:8])
    now = live_open
    emitted = 8
    per = ticks_per_minute(interval)
    for gap in (50, 900, 1200, 100, 400, 800, 2000):
        now += timedelta(milliseconds=gap)
        if now >= live_open + timedelta(minutes=1):
            break
        stamps = due_live_stamps(stream.candles.current, now, interval)
        _feed(stream, stamps)
        emitted += len(stamps)
    leftover = remaining_ticks(stream.candles.current, interval)
    _feed(stream, leftover)
    emitted += len(leftover)
    assert emitted == per
    assert stream.candles.current is not None
    assert int(stream.candles.current.volume) == per
