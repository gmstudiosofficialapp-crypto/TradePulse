# TradePulse Backend

Python FastAPI service for the TradePulse OTC **demo** simulator.

Simulated market engine, REST quotes, candle history, and WebSocket streaming
are included. Authentication/trading execution are not.

## Run

From `backend/` with the repo root on `PYTHONPATH`:

```bash
cd backend
.\.venv\Scripts\activate
$env:PYTHONPATH="D:\TradePulse"
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

- Health: `GET http://127.0.0.1:8000/health`
- Quotes: `GET http://127.0.0.1:8000/api/market/quotes`
- Candles: `GET http://127.0.0.1:8000/api/market/candles?asset=BTC/USD-OTC`
- Socket: `ws://127.0.0.1:8000/ws/market`
