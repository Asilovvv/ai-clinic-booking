"""Password hashing and bearer-token authentication."""
import hashlib
import hmac
import secrets

from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from .db import Database, get_db

_bearer = HTTPBearer(auto_error=False)


def hash_password(password: str) -> str:
    salt = secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), 100_000).hex()
    return f"{salt}${digest}"


def verify_password(password: str, stored: str) -> bool:
    salt, digest = stored.split("$", 1)
    check = hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), 100_000).hex()
    return hmac.compare_digest(check, digest)


def issue_token(db: Database, user_id: int) -> str:
    token = secrets.token_urlsafe(32)
    db.execute("INSERT INTO tokens (token, user_id) VALUES (?, ?)", (token, user_id))
    return token


def current_user(
    creds: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: Database = Depends(get_db),
) -> dict:
    if creds is None:
        raise HTTPException(status_code=401, detail="Not authenticated")
    user = db.one(
        "SELECT u.id, u.name, u.email FROM users u JOIN tokens t ON t.user_id = u.id WHERE t.token = ?",
        (creds.credentials,),
    )
    if user is None:
        raise HTTPException(status_code=401, detail="Invalid token")
    return user
