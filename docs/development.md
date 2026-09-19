# Development

## Prerequisites

- Flutter SDK (web enabled)
- Python 3.11+
- PostgreSQL (later; not required for foundation)

## Frontend

```bash
cd frontend
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

The Flutter project lives only in `frontend/`. Do not run `flutter create` at
the TradePulse repository root.

## Backend

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
pytest
uvicorn app.main:app --reload
```

`GET http://127.0.0.1:8000/health` should return `{"status":"ok",...}`.

## Engines

`market_engine/` and `signal_engine/` are empty packages. Add tests under each
`tests/` directory when those phases start.

## Conventions

- Keep feature work inside the matching module.
- Do not add broker SDKs or payment processors.
- Prefer small, named packages over a single mixed codebase.
