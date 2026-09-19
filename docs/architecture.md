# Architecture

TradePulse is a modular OTC **demo** trading simulator.

## Modules

| Module | Role |
| --- | --- |
| `frontend/` | Flutter + Flutter Web client |
| `backend/` | FastAPI API and WebSocket gateway |
| `market_engine/` | Internal simulated OTC market |
| `signal_engine/` | Automatic BUY / SELL / NO SIGNAL logic on closed 1m candles |
| `private_signal_app/` | Isolated PRIVATE TEST / GROUND TRUTH companion |
| `database/` | PostgreSQL-ready schema; runtime uses in-memory stores |

## Principles

- Demo-only: `LIVE_TRADING_ENABLED = false`. No real-money execution.
- Internal market only: no Binance, Deriv, Quotex, or other broker feeds.
- Public signal engine never receives future/ground-truth data.
- Frontend talks to `backend/` only.

## Data flow

```
OTC Market Engine
       │
       ├── Current Market Data
       │       ↓
       │   Normal Signal Engine
       │       ↓
       │   TradePulse Website
       │
       └── Ground Truth / Future Outcome
               ↓
           Private Signal App
```
