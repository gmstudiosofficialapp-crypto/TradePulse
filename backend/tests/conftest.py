import os

os.environ.setdefault("TRADEPULSE_HISTORY", "24")
os.environ.setdefault("TRADEPULSE_WARMUP_TICKS", "3")
os.environ.setdefault("TRADEPULSE_PERSISTENCE", "memory")

from app.core.firebase_auth import FirebaseUser, set_token_verifier


def _test_verify(token: str) -> FirebaseUser:
    if token.startswith("invalid") or token == "expired":
        from fastapi import HTTPException

        raise HTTPException(status_code=401, detail="Invalid or expired token")
    if "|" in token:
        uid, email = token.split("|", 1)
        return FirebaseUser(uid=uid, email=email, name="Test User")
    return FirebaseUser(uid=token, email=f"{token}@example.com", name="Test User")


set_token_verifier(_test_verify)
