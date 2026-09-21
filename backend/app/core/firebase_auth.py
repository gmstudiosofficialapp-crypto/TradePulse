from __future__ import annotations

import base64
import json
import os
from dataclasses import dataclass
from typing import Annotated, Callable

from fastapi import Depends, Header, HTTPException
from firebase_admin import auth

from app.core.firebase_admin_app import FirebaseAdminConfigError, init_firebase_admin

TokenVerifier = Callable[[str], "FirebaseUser"]
_verifier: TokenVerifier | None = None
_ISSUER_PREFIX = "https://securetoken.google.com/"


@dataclass(frozen=True, slots=True)
class FirebaseUser:
    uid: str
    email: str = ""
    name: str = ""


def set_token_verifier(verifier: TokenVerifier | None) -> TokenVerifier | None:
    global _verifier
    previous = _verifier
    _verifier = verifier
    return previous


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


def signal_feed_project_ids() -> tuple[str, ...]:
    """Projects allowed to call the Future Signal feed.

    The TradePulse project (FIREBASE_PROJECT_ID, default wallet-operator) is
    always included. Additional projects come only from
    TRUSTED_FIREBASE_PROJECT_IDS on the server.
    """
    primary = os.getenv("FIREBASE_PROJECT_ID", "wallet-operator").strip() or "wallet-operator"
    configured = os.getenv("TRUSTED_FIREBASE_PROJECT_IDS", "")
    projects: list[str] = []
    for item in (primary, *configured.split(",")):
        project_id = item.strip()
        if project_id and project_id not in projects:
            projects.append(project_id)
    return tuple(projects)


def _unverified_payload(token: str) -> dict:
    parts = token.split(".")
    if len(parts) != 3 or not all(parts):
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    try:
        padded = parts[1] + "=" * (-len(parts[1]) % 4)
        raw = base64.urlsafe_b64decode(padded.encode("ascii"))
        payload = json.loads(raw.decode("utf-8"))
    except (ValueError, UnicodeError, json.JSONDecodeError):
        raise HTTPException(status_code=401, detail="Invalid or expired token") from None
    if not isinstance(payload, dict):
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    return payload


def _app_for_project(project_id: str):
    import firebase_admin

    default_app = init_firebase_admin()
    if project_id == default_app.project_id:
        return default_app
    name = f"signal-feed-{project_id}"
    try:
        return firebase_admin.get_app(name)
    except ValueError:
        return firebase_admin.initialize_app(
            default_app.credential,
            {"projectId": project_id},
            name=name,
        )


def _admin_verify_project(token: str, project_id: str) -> dict:
    decoded = auth.verify_id_token(token, app=_app_for_project(project_id))
    if not isinstance(decoded, dict):
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    return decoded


def _user_from_verified_claims(claims: dict, project_id: str) -> FirebaseUser:
    audience = claims.get("aud")
    issuer = claims.get("iss")
    uid = claims.get("uid") or claims.get("sub")
    firebase_claims = claims.get("firebase")
    expected_issuer = f"{_ISSUER_PREFIX}{project_id}"
    if audience != project_id or issuer != expected_issuer:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    if not isinstance(uid, str) or not uid:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    if claims.get("sub") not in (None, uid):
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    if not isinstance(firebase_claims, dict) or not firebase_claims.get("sign_in_provider"):
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    return FirebaseUser(
        uid=uid,
        email=str(claims.get("email") or ""),
        name=str(claims.get("name") or ""),
    )


def verify_signal_feed_token(token: str) -> FirebaseUser:
    """Verify an ID token for the Future Signal feed only.

    Trading and other routes keep using verify_id_token(), which stays bound
    to the default TradePulse Firebase app.
    """
    if _verifier is not None:
        return _verifier(token)
    if not isinstance(token, str) or not token.strip():
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    unverified = _unverified_payload(token.strip())
    audience = unverified.get("aud")
    if not isinstance(audience, str) or audience not in signal_feed_project_ids():
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    try:
        verified = _admin_verify_project(token.strip(), audience)
    except FirebaseAdminConfigError:
        raise
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=401, detail="Invalid or expired token") from exc
    return _user_from_verified_claims(verified, audience)


def require_signal_feed_user(
    authorization: Annotated[str | None, Header()] = None,
) -> FirebaseUser:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Authorization Bearer token required")
    token = authorization[7:].strip()
    if not token:
        raise HTTPException(status_code=401, detail="Authorization Bearer token required")
    try:
        return verify_signal_feed_token(token)
    except FirebaseAdminConfigError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=401, detail="Invalid or expired token") from exc


SignalFeedUser = Annotated[FirebaseUser, Depends(require_signal_feed_user)]
