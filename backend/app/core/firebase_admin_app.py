from __future__ import annotations

import json
import os
from functools import lru_cache

import firebase_admin
from firebase_admin import credentials, firestore


class FirebaseAdminConfigError(RuntimeError):
    pass


def parse_service_account_json(raw: str) -> dict:
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise FirebaseAdminConfigError(
            "FIREBASE_SERVICE_ACCOUNT_JSON is not valid JSON."
        ) from exc
    if not isinstance(data, dict) or not data.get("private_key") or not data.get("client_email"):
        raise FirebaseAdminConfigError(
            "FIREBASE_SERVICE_ACCOUNT_JSON must be a Firebase service-account object."
        )
    return data


def _credentials_path() -> str | None:
    return os.getenv("GOOGLE_APPLICATION_CREDENTIALS") or os.getenv(
        "FIREBASE_SERVICE_ACCOUNT"
    )


def _admin_credential():
    raw = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON")
    if raw and raw.strip():
        return credentials.Certificate(parse_service_account_json(raw))
    path = _credentials_path()
    if not path:
        raise FirebaseAdminConfigError(
            "Firebase Admin credentials are missing. Set FIREBASE_SERVICE_ACCOUNT_JSON "
            "or GOOGLE_APPLICATION_CREDENTIALS for project wallet-operator."
        )
    if not os.path.isfile(path):
        raise FirebaseAdminConfigError(
            f"Firebase Admin credential file not found: {path}"
        )
    return credentials.Certificate(path)


@lru_cache(maxsize=1)
def init_firebase_admin():
    if firebase_admin._apps:
        return firebase_admin.get_app()
    cred = _admin_credential()
    return firebase_admin.initialize_app(
        cred,
        {"projectId": os.getenv("FIREBASE_PROJECT_ID", "wallet-operator")},
    )


def firestore_client():
    init_firebase_admin()
    return firestore.client()
