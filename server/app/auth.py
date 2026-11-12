"""Accounts: password hashing, bearer tokens and role checks."""
import hashlib
import hmac
import secrets

from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from .clock import stamp
from .db import get_db, tokens, users

_bearer = HTTPBearer(auto_error=False)

ROLES = ("customer", "owner")


def hash_password(password: str) -> str:
    salt = secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), 100_000).hex()
    return f"{salt}${digest}"


def verify_password(password: str, stored: str) -> bool:
    if "$" not in stored:
        return False  # seeded accounts that nobody can sign in to
    salt, digest = stored.split("$", 1)
    check = hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), 100_000).hex()
    return hmac.compare_digest(check, digest)


def public_user(row: dict) -> dict:
    return {"id": row["id"], "name": row["name"], "email": row["email"], "role": row["role"], "phone": row["phone"] or ""}


def create_user(db, name: str, email: str, password: str | None, role: str = "customer", phone: str | None = None) -> dict:
    """Create an account. `password=None` makes an account that cannot sign in."""
    user_id = db.insert(
        users,
        name=name.strip(),
        email=email.lower().strip(),
        password_hash=hash_password(password) if password else "!",
        role=role,
        phone=(phone or "").strip() or None,
        created_at=stamp(),
    )
    return public_user(db.one("SELECT * FROM users WHERE id = :id", id=user_id))


def find_user(db, email: str) -> dict | None:
    return db.one("SELECT * FROM users WHERE email = :email", email=email.lower().strip())


def issue_token(db, user_id: int) -> str:
    token = secrets.token_urlsafe(32)
    db.insert(tokens, token=token, user_id=user_id)
    return token


def current_user(creds: HTTPAuthorizationCredentials | None = Depends(_bearer), db=Depends(get_db)) -> dict:
    if creds is None:
        raise HTTPException(status_code=401, detail="Войдите в аккаунт")
    row = db.one(
        "SELECT u.* FROM users u JOIN tokens t ON t.user_id = u.id WHERE t.token = :token",
        token=creds.credentials,
    )
    if row is None:
        raise HTTPException(status_code=401, detail="Сессия устарела, войдите снова")
    return public_user(row)


def current_owner(user: dict = Depends(current_user)) -> dict:
    if user["role"] != "owner":
        raise HTTPException(status_code=403, detail="Раздел доступен только владельцам бизнеса")
    return user
