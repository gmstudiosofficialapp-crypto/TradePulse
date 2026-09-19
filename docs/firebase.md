# Firebase (wallet-operator)

TradePulse uses the existing Firebase project **wallet-operator**. Do not create another project.

## Console (manual)

1. Authentication → Sign-in method → **Email/Password** enabled.
2. Authentication → Settings → Authorized domains:
   - `localhost`
   - `127.0.0.1`
   - add a production host only when you have one
3. Firestore → deploy `firestore.rules` and `firestore.indexes.json` from this repo.
4. Create a service account key for the **backend only**. Save the JSON outside git and set:

```
GOOGLE_APPLICATION_CREDENTIALS=C:\path\to\wallet-operator-adminsdk.json
TRADEPULSE_PERSISTENCE=firestore
```

Never put that JSON in Flutter or commit it.

## Local run

Backend (after credentials are set):

```
cd backend
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
$env:TRADEPULSE_PERSISTENCE="firestore"
$env:GOOGLE_APPLICATION_CREDENTIALS="C:\path\to\serviceAccount.json"
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Frontend:

```
cd frontend
flutter pub get
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8090
```

Tests use in-memory stores and a fake token verifier (`TRADEPULSE_PERSISTENCE=memory` in `backend/tests/conftest.py`).
