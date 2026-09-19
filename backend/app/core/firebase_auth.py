from __future__ import annotations

from dataclasses import dataclass
from typing import Annotated, Callable

from fastapi import Depends, Header, HTTPException
from firebase_admin import auth

from app.core.firebase_admin_app import FirebaseAdminConfigError, init_firebase_admin

TokenVerifier = Callable[[str], "FirebaseUser"]
_verifier: TokenVerifier | None = None


@dataclass(frozen=True, slots=True)
class FirebaseUser:
    uid: str
    email: str = ""
    name: str = ""


def set_token_verifier(verifier: TokenVerifier | None) -> None:
    global _verifier
    _verifier = verifier


def verify_id_token(token: str) -> FirebaseUser:
    if _verifier is not None:
        return _verifier(token)
    try:
        init_firebase_admin()
        decoded = auth.verify_id_token(token)
    except FirebaseAdminConfigError:
        raise
    except Exception as exc:
        raise HTTPException(status_code=401, detail="Invalid or expired token") from exc
    uid = decoded.get("uid")
    if not uid:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    return FirebaseUser(
        uid=str(uid),
        email=str(decoded.get("email") or ""),
        name=str(decoded.get("name") or ""),
    )


def require_user(
    authorization: Annotated[str | None, Header()] = None,
) -> FirebaseUser:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Authorization Bearer token required")
    token = authorization[7:].strip()
    if not token:
        raise HTTPException(status_code=401, detail="Authorization Bearer token required")
    try:
        return verify_id_token(token)
    except FirebaseAdminConfigError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=401, detail="Invalid or expired token") from exc


AuthUser = Annotated[FirebaseUser, Depends(require_user)]
