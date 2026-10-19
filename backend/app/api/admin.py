from typing import Any

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.core.admin_auth import AdminUser, authenticate_admin
from app.services.withdraw import (
    WithdrawError,
    approve_withdrawal,
    list_admin_withdrawals,
    reject_withdrawal,
)

router = APIRouter(prefix="/api/admin", tags=["admin"])


class AdminLoginBody(BaseModel):
    username: Any = None
    password: Any = None


class AdminRejectBody(BaseModel):
    reason: Any = None


def _raise(error: WithdrawError) -> None:
    status = 400
    if error.code == "not_found":
        status = 404
    elif error.code in ("pending", "conflict"):
        status = 409
    raise HTTPException(status_code=status, detail=error.message)


@router.post("/login")
def admin_login(body: AdminLoginBody) -> dict:
    token = authenticate_admin(str(body.username or ""), str(body.password or ""))
    return {"ok": True, "token": token, "role": "admin"}


@router.get("/withdrawals")
def admin_withdrawals(
    admin: AdminUser,
    status: str | None = None,
    search: str | None = None,
) -> dict:
    del admin
    return {"withdrawals": list_admin_withdrawals(status=status, search=search)}


@router.post("/withdrawals/{request_id}/approve")
def admin_approve(request_id: str, admin: AdminUser) -> dict:
    try:
        return approve_withdrawal(request_id, admin.username)
    except WithdrawError as exc:
        _raise(exc)
        raise


@router.post("/withdrawals/{request_id}/reject")
def admin_reject(request_id: str, body: AdminRejectBody, admin: AdminUser) -> dict:
    try:
        return reject_withdrawal(request_id, admin.username, body.reason)
    except WithdrawError as exc:
        _raise(exc)
        raise
