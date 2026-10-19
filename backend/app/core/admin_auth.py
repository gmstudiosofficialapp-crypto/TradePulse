from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import time
from dataclasses import dataclass
from typing import Annotated

from fastapi import Depends, Header, HTTPException

TOKEN_TTL_SECONDS = 12 * 60 * 60


class AdminConfigError(RuntimeError):
    pass


@dataclass(frozen=True, slots=True)
class AdminPrincipal:
    username: str


def _credentials() -> tuple[str, str]:
    username = os.getenv("ADMIN_USERNAME", "").strip()
    password = os.getenv("ADMIN_PASSWORD", "")
    if not username or not password:
        raise AdminConfigError("Admin credentials are not configured")
    return username, password


def _session_secret() -> bytes:
    explicit = os.getenv("ADMIN_SESSION_SECRET", "").strip()
    if explicit:
        return hashlib.sha256(explicit.encode("utf-8")).digest()
    username, password = _credentials()
    return hashlib.sha256(
        f"{username}\0{password}\0tradepulse-admin-session".encode("utf-8")
    ).digest()


def _digest_eq(left: str, right: str) -> bool:
    return hmac.compare_digest(
        hashlib.sha256(left.encode("utf-8")).digest(),
        hashlib.sha256(right.encode("utf-8")).digest(),
    )


def _b64url(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def _b64url_decode(value: str) -> bytes:
    padded = value + "=" * (-len(value) % 4)
    return base64.urlsafe_b64decode(padded.encode("ascii"))


def issue_admin_token(username: str) -> str:
    payload = {"role": "admin", "sub": username, "exp": int(time.time()) + TOKEN_TTL_SECONDS}
    body = _b64url(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
    signature = hmac.new(_session_secret(), body.encode("ascii"), hashlib.sha256).hexdigest()
    return f"tp1.{body}.{signature}"


def verify_admin_token(token: str) -> AdminPrincipal:
    parts = token.split(".")
    if len(parts) != 3 or parts[0] != "tp1":
        raise HTTPException(status_code=401, detail="Invalid or expired admin session")
    body, signature = parts[1], parts[2]
    expected = hmac.new(_session_secret(), body.encode("ascii"), hashlib.sha256).hexdigest()
    if not hmac.compare_digest(expected, signature):
        raise HTTPException(status_code=401, detail="Invalid or expired admin session")
    try:
        payload = json.loads(_b64url_decode(body).decode("utf-8"))
    except (ValueError, UnicodeError, json.JSONDecodeError):
        raise HTTPException(status_code=401, detail="Invalid or expired admin session") from None
    if payload.get("role") != "admin" or not isinstance(payload.get("sub"), str):
        raise HTTPException(status_code=401, detail="Invalid or expired admin session")
    exp = payload.get("exp")
    if not isinstance(exp, int) or exp < int(time.time()):
        raise HTTPException(status_code=401, detail="Invalid or expired admin session")
    return AdminPrincipal(username=payload["sub"])


def authenticate_admin(username: str, password: str) -> str:
    try:
        expected_user, expected_password = _credentials()
    except AdminConfigError as exc:
        raise HTTPException(status_code=503, detail="Admin is not configured") from exc
    if not _digest_eq(username.strip(), expected_user) or not _digest_eq(password, expected_password):
        raise HTTPException(status_code=401, detail="Invalid admin credentials")
    return issue_admin_token(expected_user)


def require_admin(
    authorization: Annotated[str | None, Header()] = None,
) -> AdminPrincipal:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Admin authorization required")
    token = authorization[7:].strip()
    if not token:
        raise HTTPException(status_code=401, detail="Admin authorization required")
    try:
        return verify_admin_token(token)
    except AdminConfigError as exc:
        raise HTTPException(status_code=503, detail="Admin is not configured") from exc


AdminUser = Annotated[AdminPrincipal, Depends(require_admin)]
