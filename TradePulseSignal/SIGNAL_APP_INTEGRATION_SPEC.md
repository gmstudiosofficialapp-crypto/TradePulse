# TradePulse ↔ Signal App integration contract

Private BTC future-book feed for `TradePulseSignal` only.  
This is **not** a public market API. Do **not** use `GET /api/private/btc-future-candles` as the production Signal App channel.

## 1. Scope

- Asset: `BTC/USD-OTC` only
- Timeframe: `1m`
- State: **1 LIVE candle + next 3 precomputed candles**
- No BUY/SELL signal logic on this channel

TradePulse generates futures from a **cloned** live RNG. Live RNG is never rewound for this feed.

## 2. Endpoints

| Channel | Path | Auth |
|---|---|---|
| HTTP snapshot | `GET /api/signal/btc-future-book` | Firebase ID token, `Authorization: Bearer <token>` |
| WebSocket | `/ws/signal-btc-future` | Same token: first JSON `auth` message, or `Authorization` header, or `?access_token=` |

Public surfaces **must not** carry this payload:

- `GET /api/market/quotes`
- `GET /api/market/candles`
- `/ws/market`

## 3. Authentication

Compatible with existing TradePulse Firebase Auth.

1. Signal App signs in with Email/Password (or any Firebase client token).
2. Sends the **ID token** (not a hardcoded secret).
3. TradePulse verifies with Firebase Admin (`verify_id_token`). Tests inject a verifier.

HTTP 401 if missing/invalid. WebSocket closes `4401` if unauthenticated.  
Firebase Admin missing → HTTP 503 / WS `1013`.

Token is never committed. Use env:

- `TRADEPULSE_BASE_URL`
- `TRADEPULSE_ID_TOKEN`

## 4. Candle identity

```
id = "{asset}|1m|{candle_start_time}"
```

Example: `BTC/USD-OTC|1m|2026-09-21T16:09:00+00:00`

- `candle_start_time` / `candle_end_time`: ISO-8601 UTC
- `candle_end_time` = start + 1 minute
- Direction: `UP` | `DOWN` | `FLAT`

## 5. Candle JSON

```json
{
  "id": "BTC/USD-OTC|1m|2026-09-21T16:10:00+00:00",
  "asset": "BTC/USD-OTC",
  "timeframe": "1m",
  "role": "FUTURE_1",
  "candle_start_time": "2026-09-21T16:10:00+00:00",
  "candle_end_time": "2026-09-21T16:11:00+00:00",
  "open": 67000.12,
  "high": 67040.0,
  "low": 66980.5,
  "close": 67022.4,
  "direction": "UP",
  "volume": 150,
  "closed": true,
  "precomputed": true,
  "simulated": true
}
```

`role`: `LIVE` | `FUTURE_1` | `FUTURE_2` | `FUTURE_3` | `CLOSED`

## 6. Envelope

```json
{
  "schema_version": 1,
  "type": "snapshot",
  "asset": "BTC/USD-OTC",
  "timeframe": "1m",
  "timezone": "UTC",
  "sequence": 14,
  "generated_at": "2026-09-21T16:09:20.400000+00:00",
  "live": { "role": "LIVE", "precomputed": false },
  "futures": ["FUTURE_1", "FUTURE_2", "FUTURE_3"],
  "future_count": 3,
  "rolling": true
}
```

`type`:

| type | When |
|---|---|
| `snapshot` | HTTP GET, WS `subscribe`, reconnect resync |
| `live_update` | BTC tick; same 3 futures, live OHLC may change |
| `roll` | Previous live closed; FUTURE_1 promoted; new FUTURE_3 |
| `authenticated` / `pong` / `error` | Control |

`roll` extra fields: `closed_live`, `closed_live_id`, `promoted_live_id`, `new_future_id`.

## 7. Rolling

At 16:09 LIVE, futures = 16:10, 16:11, 16:12.

On 16:09 close:

1. 16:10 becomes LIVE (`promoted_live_id`)
2. 16:11 / 16:12 stay FUTURE_1 / FUTURE_2 (same ids/OHLC)
3. 16:13 is new FUTURE_3 (`new_future_id`)

Clients **replace** local state from the envelope `live` + `futures` arrays. Do not splice locally unless ids match.

## 8. WebSocket session

```
→ { "type": "auth", "token": "<firebase-id-token>" }
← { "type": "authenticated", "asset": "BTC/USD-OTC" }
→ { "type": "subscribe" }
← snapshot
← live_update | roll …
→ { "type": "ping" }
← { "type": "pong" }
```

## 9. Reconnect / resync

On disconnect: mark DISCONNECTED, exponential backoff (1s, 2s, 5s, max 15s).

On reconnect:

1. `GET /api/signal/btc-future-book` (Bearer)
2. Apply `snapshot` (always accepted)
3. Open WS, auth, subscribe
4. Apply later messages only if `sequence` > last applied

## 10. Stale / malformed

Reject and keep previous good state if:

- `schema_version` ≠ 1
- `asset` ≠ `BTC/USD-OTC`
- `futures` length ≠ 3
- missing OHLC / invalid direction
- `live_update` or `roll` with `sequence` ≤ last sequence

After repeated rejects, force HTTP snapshot resync.

## 11. What is not in this feed

RNG internals, ground-truth peek, public quotes, BUY/SELL signals, ML/RSI/MACD.
