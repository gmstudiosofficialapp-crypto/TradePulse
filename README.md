# TradePulse

Polished broker-style **OTC demo** trading simulator.

This repository implements Phases 1–3: UI/auth, simulated OTC market, automatic
BUY/SELL/NO SIGNAL engine, demo trading, and a private ground-truth app.

## What TradePulse is

- 20 OTC assets
- Live **simulated** OTC market (internal engine)
- 1-minute candles
- Automatic signals (BUY / SELL / NO SIGNAL)
- Demo-only trading
- No real-money / live trade execution

## Tech stack

| Layer | Choice |
| --- | --- |
| Frontend | Flutter, Flutter Web, Dart |
| Backend | Python, FastAPI |
| Realtime | WebSocket (later) |
| Database | PostgreSQL (later) |
| Private signal app | Flutter (later) |

## Repository structure

```
TradePulse/
├── frontend/              Flutter + Flutter Web client
├── backend/               FastAPI API
├── market_engine/         Simulated OTC market (later)
├── signal_engine/         Automatic signals (later)
├── private_signal_app/    Companion Flutter app (later)
├── database/              PostgreSQL schemas/migrations (later)
├── docs/                  Architecture, development, roadmap
└── README.md
```

## Frontend layout

```
frontend/
├── lib/
│   ├── core/
│   │   ├── constants/
│   │   ├── theme/
│   │   ├── routes/
│   │   ├── utils/
│   │   └── services/
│   ├── models/
│   ├── screens/
│   ├── widgets/
│   └── main.dart
├── assets/
│   ├── images/
│   ├── icons/
│   └── animations/
└── pubspec.yaml
```

## Backend layout

```
backend/
├── app/
│   ├── api/
│   ├── core/
│   ├── models/
│   ├── schemas/
│   ├── services/
│   └── main.py
├── tests/
└── requirements.txt
```

## Quick start

### Flutter Web

```bash
cd frontend
flutter pub get
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8090
```

Open http://127.0.0.1:8090

### FastAPI

```bash
cd backend
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --host 127.0.0.1 --port 8000
```

API: http://127.0.0.1:8000  
Market WS: ws://127.0.0.1:8000/ws/market  
Private WS: ws://127.0.0.1:8000/ws/private-reference

### Private ground-truth app (not a user feature)

```bash
cd private_signal_app
flutter pub get
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8091
```

Open http://127.0.0.1:8091

## Roadmap

See [docs/roadmap.md](docs/roadmap.md).

1. **Phase 1** — Auth, profile, settings, navigation, UI foundation
2. **Phase 2** — Simulated OTC market, 20 assets, ticks, 1-minute candles, WebSocket chart
3. **Phase 3** — Signals, demo trading, statistics, private signal app

## Docs

- [Architecture](docs/architecture.md)
- [Development](docs/development.md)
- [Roadmap](docs/roadmap.md)

## Constraints

- Demo simulator only
- No live broker integrations
- No real-money payments or execution
