"""REST API for the AI Clinic Booking mobile app."""
import os
from pathlib import Path

from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from . import assistant, scheduling
from .auth import current_user, hash_password, issue_token, verify_password
from .db import Database, get_db

def _load_env_file() -> None:
    """Read server/.env (KEY=VALUE lines) without overriding real env vars."""
    env = Path(__file__).resolve().parent.parent / ".env"
    if not env.exists():
        return
    for line in env.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            if value.strip():
                os.environ.setdefault(key.strip(), value.strip())


_load_env_file()

app = FastAPI(title="AI Clinic Booking API", version="1.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])


class RegisterIn(BaseModel):
    name: str = Field(min_length=2, max_length=60)
    email: str = Field(pattern=r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
    password: str = Field(min_length=6)


class LoginIn(BaseModel):
    email: str
    password: str


class BookIn(BaseModel):
    doctor_id: int
    start: str


class HistoryItem(BaseModel):
    role: str
    text: str


class ChatIn(BaseModel):
    message: str = Field(min_length=1, max_length=1000)
    history: list[HistoryItem] = []


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/auth/register")
def register(body: RegisterIn, db: Database = Depends(get_db)):
    email = body.email.lower().strip()
    if db.one("SELECT id FROM users WHERE email = ?", (email,)):
        raise HTTPException(status_code=409, detail="Пользователь с таким email уже есть")
    user_id = db.execute(
        "INSERT INTO users (name, email, password_hash) VALUES (?, ?, ?)",
        (body.name.strip(), email, hash_password(body.password)),
    )
    user = {"id": user_id, "name": body.name.strip(), "email": email}
    return {"token": issue_token(db, user_id), "user": user}


@app.post("/auth/login")
def login(body: LoginIn, db: Database = Depends(get_db)):
    row = db.one("SELECT * FROM users WHERE email = ?", (body.email.lower().strip(),))
    if row is None or not verify_password(body.password, row["password_hash"]):
        raise HTTPException(status_code=401, detail="Неверный email или пароль")
    user = {"id": row["id"], "name": row["name"], "email": row["email"]}
    return {"token": issue_token(db, row["id"]), "user": user}


@app.get("/me")
def me(user: dict = Depends(current_user)):
    return user


@app.get("/doctors")
def doctors(db: Database = Depends(get_db)):
    return scheduling.list_doctors(db)


@app.get("/doctors/{doctor_id}/slots")
def doctor_slots(doctor_id: int, db: Database = Depends(get_db)):
    if db.one("SELECT id FROM doctors WHERE id = ?", (doctor_id,)) is None:
        raise HTTPException(status_code=404, detail="Врач не найден")
    return scheduling.find_slots(db, [doctor_id], limit=12)


@app.get("/appointments")
def my_appointments(user: dict = Depends(current_user), db: Database = Depends(get_db)):
    return scheduling.user_appointments(db, user["id"])


@app.post("/appointments", status_code=201)
def create_appointment(body: BookIn, user: dict = Depends(current_user), db: Database = Depends(get_db)):
    try:
        return scheduling.book(db, user["id"], body.doctor_id, body.start)
    except scheduling.BookingError as e:
        raise HTTPException(status_code=400, detail=str(e))


@app.delete("/appointments/{appointment_id}", status_code=204)
def cancel_appointment(appointment_id: int, user: dict = Depends(current_user), db: Database = Depends(get_db)):
    row = db.one("SELECT id FROM appointments WHERE id = ? AND user_id = ?", (appointment_id, user["id"]))
    if row is None:
        raise HTTPException(status_code=404, detail="Запись не найдена")
    db.execute("DELETE FROM appointments WHERE id = ?", (appointment_id,))


@app.post("/chat")
def chat(body: ChatIn, user: dict = Depends(current_user), db: Database = Depends(get_db)):
    history = [h.model_dump() for h in body.history]
    return assistant.answer(db, user, body.message, history)
