# Signal Engine

Analyzes **closed 1-minute candles only** and may emit:

- BUY
- SELL
- NO SIGNAL

Confidence is a model score, not a guarantee. The engine does not receive
future/ground-truth market data. That reference feed is isolated to
`private_signal_app/`.
