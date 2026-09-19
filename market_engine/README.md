# Market Engine

Internal **simulated** OTC market. No broker APIs.

- `config/` asset parameters (admin-ready, no admin UI)
- `generators/` continuous price model
- `services/` ticks, 1-minute UTC candles, memory store, runtime loop

Start via the FastAPI backend lifespan. Frontend is display-only.
