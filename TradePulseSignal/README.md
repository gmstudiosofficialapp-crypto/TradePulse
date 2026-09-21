# TradePulseSignal

Separate BTC future-book research app. It only receives TradePulse private live + next-3 1m candles. No signal algorithm.

See `SIGNAL_APP_INTEGRATION_SPEC.md`.

```
set TRADEPULSE_BASE_URL=http://127.0.0.1:8000
set TRADEPULSE_ID_TOKEN=your-firebase-id-token
uvicorn app.main:app --host 127.0.0.1 --port 8091
```

Open http://127.0.0.1:8091 and paste the Firebase ID token. Do not commit tokens.
