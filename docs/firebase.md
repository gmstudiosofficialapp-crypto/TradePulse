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

## Password reset (Firebase native)

Forgot Password uses Firebase Authentication `sendPasswordResetEmail`. TradePulse does **not** send OTP mail through the backend.

Console:

1. Authentication → Templates → Password reset → customize action URL to the TradePulse web origin, for example:
   - local: `http://127.0.0.1:8090/#/reset-password`
   - production host once it exists
2. Authorized domains must include that host.
3. Leave Email/Password enabled. Do not configure SendGrid, SMTP, or Resend for this flow.

The email link includes Firebase's `mode=resetPassword` and `oobCode`. Flutter parses those parameters once on landing, verifies with `verifyPasswordResetCode`, and updates the Firebase password with `confirmPasswordReset`. Action codes are never stored in Firestore or local storage.

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
