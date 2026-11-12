"""REST API of Smile AI: catalog, bookings and AI chat for clients, a cabinet for owners."""
import os
from contextlib import asynccontextmanager
from datetime import date
from pathlib import Path
from typing import Literal

from fastapi import Depends, FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field


def _load_env_file() -> None:
    """Read server/.env (KEY=VALUE lines) without overriding real environment variables."""
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

from . import assistant, auth, businesses, clock, scheduling, seed  # noqa: E402
from .catalog import public_categories  # noqa: E402
from .db import get_db  # noqa: E402

VERSION = "3.0.0"


@asynccontextmanager
async def lifespan(_: FastAPI):
    seed.ensure_seed(get_db())
    yield


app = FastAPI(title="Smile AI API", version=VERSION, lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])


# ------------------------------------------------------------------ models

class RegisterIn(BaseModel):
    name: str = Field(min_length=2, max_length=60)
    email: str = Field(pattern=r"^[^@\s]+@[^@\s]+\.[^@\s]+$", max_length=160)
    password: str = Field(min_length=6, max_length=100)
    role: Literal["customer", "owner"] = "customer"
    phone: str | None = Field(default=None, max_length=32)


class LoginIn(BaseModel):
    email: str
    password: str


class DemoIn(BaseModel):
    role: Literal["customer", "owner"]


class BookIn(BaseModel):
    service_id: int
    specialist_id: int | None = None
    start: str
    note: str = Field(default="", max_length=300)
    source: Literal["app", "chat"] = "app"


class RescheduleIn(BaseModel):
    start: str


class ReviewIn(BaseModel):
    rating: int = Field(ge=1, le=5)
    comment: str = Field(default="", max_length=500)


class HistoryItem(BaseModel):
    role: str
    text: str


class ChatIn(BaseModel):
    message: str = Field(min_length=1, max_length=1000)
    history: list[HistoryItem] = []
    category: str | None = None
    business_id: int | None = None
    specialist_id: int | None = None


class BusinessIn(BaseModel):
    category: str
    name: str = Field(min_length=2, max_length=80)
    description: str = Field(default="", max_length=500)
    address: str = Field(default="", max_length=160)
    phone: str = Field(default="", max_length=32)
    open_hour: int = Field(default=9, ge=0, le=23)
    close_hour: int = Field(default=18, ge=1, le=24)
    working_days: list[int] = [0, 1, 2, 3, 4, 5]
    use_template: bool = True


class BusinessPatch(BaseModel):
    name: str | None = Field(default=None, max_length=80)
    description: str | None = Field(default=None, max_length=500)
    address: str | None = Field(default=None, max_length=160)
    phone: str | None = Field(default=None, max_length=32)
    open_hour: int | None = Field(default=None, ge=0, le=23)
    close_hour: int | None = Field(default=None, ge=1, le=24)
    working_days: list[int] | None = None
    is_active: bool | None = None


class ServiceIn(BaseModel):
    name: str = Field(min_length=2, max_length=80)
    description: str = Field(default="", max_length=300)
    duration_min: int
    price: int = Field(ge=0, le=1_000_000)
    specialist_ids: list[int] | None = None


class SpecialistIn(BaseModel):
    name: str = Field(min_length=2, max_length=80)
    title: str = Field(default="", max_length=80)
    service_ids: list[int] | None = None


class StatusIn(BaseModel):
    status: Literal["booked", "completed", "no_show", "cancelled"]


class OwnerBookIn(BaseModel):
    service_id: int
    specialist_id: int | None = None
    start: str
    client_name: str = Field(min_length=2, max_length=80)
    client_phone: str = Field(default="", max_length=32)
    note: str = Field(default="", max_length=300)


def _bad_request(error: Exception) -> HTTPException:
    return HTTPException(status_code=400, detail=str(error))


def _parse_day(value: str | None) -> date | None:
    if not value:
        return None
    try:
        return date.fromisoformat(value)
    except ValueError:
        raise HTTPException(status_code=400, detail="Дата должна быть в формате ГГГГ-ММ-ДД")


# ---------------------------------------------------------- service routes

@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/config")
def config():
    """What the app needs to know before sign-in."""
    return {"name": "Smile AI", "version": VERSION, "demo": seed.demo_enabled(),
            "ai": bool(os.getenv("LLM_API_KEY"))}


# -------------------------------------------------------------------- auth

def _session(db, user: dict) -> dict:
    return {"token": auth.issue_token(db, user["id"]), "user": user}


@app.post("/auth/register")
def register(body: RegisterIn, db=Depends(get_db)):
    if auth.find_user(db, body.email):
        raise HTTPException(status_code=409, detail="Пользователь с таким email уже есть")
    return _session(db, auth.create_user(db, body.name, body.email, body.password, body.role, body.phone))


@app.post("/auth/login")
def login(body: LoginIn, db=Depends(get_db)):
    row = auth.find_user(db, body.email)
    if row is None or not auth.verify_password(body.password, row["password_hash"]):
        raise HTTPException(status_code=401, detail="Неверный email или пароль")
    return _session(db, auth.public_user(row))


@app.post("/auth/demo")
def demo_login(body: DemoIn, db=Depends(get_db)):
    """One-tap sign-in to the demo client or demo owner (only when demo data is on)."""
    email = seed.DEMO_OWNER_EMAIL if body.role == "owner" else seed.DEMO_CUSTOMER_EMAIL
    row = auth.find_user(db, email) if seed.demo_enabled() else None
    if row is None:
        raise HTTPException(status_code=404, detail="Демо-режим выключен")
    return _session(db, auth.public_user(row))


@app.get("/me")
def me(user: dict = Depends(auth.current_user)):
    return user


# ----------------------------------------------------------------- catalog

@app.get("/categories")
def categories():
    return public_categories()


@app.get("/businesses")
def list_businesses(category: str | None = None, db=Depends(get_db)):
    return businesses.list_businesses(db, category)


@app.get("/businesses/{business_id}")
def get_business(business_id: int, db=Depends(get_db)):
    business = businesses.get_business(db, business_id)
    if business is None:
        raise HTTPException(status_code=404, detail="Заведение не найдено")
    return business


@app.get("/businesses/{business_id}/slots")
def business_slots(
    business_id: int,
    service_id: int,
    specialist_id: int | None = None,
    day: str | None = Query(default=None, alias="date"),
    limit: int = Query(default=48, ge=1, le=96),
    db=Depends(get_db),
):
    """Free start times of a service: every 30 minutes of one day, or the nearest ones."""
    offers = scheduling.load_offers(db, service_ids=[service_id], business_id=business_id, specialist_id=specialist_id)
    return scheduling.find_slots(db, offers, _parse_day(day), limit=limit)


# ---------------------------------------------------------------- bookings

@app.get("/appointments")
def my_appointments(user: dict = Depends(auth.current_user), db=Depends(get_db)):
    return scheduling.customer_appointments(db, user["id"])


@app.post("/appointments", status_code=201)
def create_appointment(body: BookIn, user: dict = Depends(auth.current_user), db=Depends(get_db)):
    try:
        return scheduling.book(db, service_id=body.service_id, start=body.start, customer_id=user["id"],
                               specialist_id=body.specialist_id, source=body.source, note=body.note)
    except scheduling.BookingError as e:
        raise _bad_request(e)


@app.patch("/appointments/{appointment_id}")
def reschedule_appointment(appointment_id: int, body: RescheduleIn, user: dict = Depends(auth.current_user),
                           db=Depends(get_db)):
    try:
        return scheduling.reschedule(db, appointment_id, body.start, customer_id=user["id"])
    except scheduling.BookingError as e:
        raise _bad_request(e)


@app.delete("/appointments/{appointment_id}")
def cancel_appointment(appointment_id: int, user: dict = Depends(auth.current_user), db=Depends(get_db)):
    try:
        return scheduling.cancel(db, appointment_id, customer_id=user["id"])
    except scheduling.BookingError as e:
        raise _bad_request(e)


@app.post("/appointments/{appointment_id}/review")
def review_appointment(appointment_id: int, body: ReviewIn, user: dict = Depends(auth.current_user),
                       db=Depends(get_db)):
    try:
        return businesses.add_review(db, user["id"], appointment_id, body.rating, body.comment)
    except businesses.BusinessError as e:
        raise _bad_request(e)


@app.post("/chat")
def chat(body: ChatIn, user: dict = Depends(auth.current_user), db=Depends(get_db)):
    history = [item.model_dump() for item in body.history]
    return assistant.answer(db, user, body.message, history, body.category, body.business_id, body.specialist_id)


# ------------------------------------------------------------------- owner

def owner_business(user: dict = Depends(auth.current_owner), db=Depends(get_db)) -> int:
    """Id of the signed-in owner's business."""
    business_id = businesses.owner_business_id(db, user["id"])
    if business_id is None:
        raise HTTPException(status_code=404, detail="Сначала создайте бизнес")
    return business_id


@app.get("/owner/business")
def owner_get_business(user: dict = Depends(auth.current_owner), db=Depends(get_db)):
    """The owner's business, or null when it has not been created yet."""
    business_id = businesses.owner_business_id(db, user["id"])
    return businesses.get_business(db, business_id, only_active=False) if business_id else None


@app.post("/owner/business", status_code=201)
def owner_create_business(body: BusinessIn, user: dict = Depends(auth.current_owner), db=Depends(get_db)):
    try:
        return businesses.create_business(db, user, body.model_dump())
    except businesses.BusinessError as e:
        raise _bad_request(e)


@app.patch("/owner/business")
def owner_update_business(body: BusinessPatch, business_id: int = Depends(owner_business), db=Depends(get_db)):
    try:
        return businesses.update_business(db, business_id, body.model_dump())
    except businesses.BusinessError as e:
        raise _bad_request(e)


@app.post("/owner/services", status_code=201)
def owner_add_service(body: ServiceIn, business_id: int = Depends(owner_business), db=Depends(get_db)):
    try:
        return businesses.save_service(db, business_id, body.model_dump())
    except businesses.BusinessError as e:
        raise _bad_request(e)


@app.patch("/owner/services/{service_id}")
def owner_update_service(service_id: int, body: ServiceIn, business_id: int = Depends(owner_business),
                         db=Depends(get_db)):
    try:
        return businesses.save_service(db, business_id, body.model_dump(), service_id)
    except businesses.BusinessError as e:
        raise _bad_request(e)


@app.delete("/owner/services/{service_id}")
def owner_delete_service(service_id: int, business_id: int = Depends(owner_business), db=Depends(get_db)):
    try:
        return businesses.delete_service(db, business_id, service_id)
    except businesses.BusinessError as e:
        raise _bad_request(e)


@app.post("/owner/specialists", status_code=201)
def owner_add_specialist(body: SpecialistIn, business_id: int = Depends(owner_business), db=Depends(get_db)):
    try:
        return businesses.save_specialist(db, business_id, body.model_dump())
    except businesses.BusinessError as e:
        raise _bad_request(e)


@app.patch("/owner/specialists/{specialist_id}")
def owner_update_specialist(specialist_id: int, body: SpecialistIn, business_id: int = Depends(owner_business),
                            db=Depends(get_db)):
    try:
        return businesses.save_specialist(db, business_id, body.model_dump(), specialist_id)
    except businesses.BusinessError as e:
        raise _bad_request(e)


@app.delete("/owner/specialists/{specialist_id}")
def owner_delete_specialist(specialist_id: int, business_id: int = Depends(owner_business), db=Depends(get_db)):
    try:
        return businesses.delete_specialist(db, business_id, specialist_id)
    except businesses.BusinessError as e:
        raise _bad_request(e)


@app.get("/owner/appointments")
def owner_appointments(day: str | None = Query(default=None, alias="date"),
                       business_id: int = Depends(owner_business), db=Depends(get_db)):
    """The schedule of one day (today by default)."""
    return scheduling.business_appointments(db, business_id, _parse_day(day) or clock.now().date())


@app.post("/owner/appointments", status_code=201)
def owner_book(body: OwnerBookIn, business_id: int = Depends(owner_business), db=Depends(get_db)):
    """Book a client who called or walked in."""
    try:
        if not scheduling.load_offers(db, service_ids=[body.service_id], business_id=business_id):
            raise scheduling.BookingError("Услуга не найдена")
        return scheduling.book(db, service_id=body.service_id, start=body.start, specialist_id=body.specialist_id,
                               source="owner", client_name=body.client_name, client_phone=body.client_phone,
                               note=body.note)
    except scheduling.BookingError as e:
        raise _bad_request(e)


@app.patch("/owner/appointments/{appointment_id}")
def owner_set_status(appointment_id: int, body: StatusIn, business_id: int = Depends(owner_business),
                     db=Depends(get_db)):
    try:
        return scheduling.set_status(db, appointment_id, body.status, business_id=business_id)
    except scheduling.BookingError as e:
        raise _bad_request(e)


@app.get("/owner/stats")
def owner_stats(days: int = Query(default=7, ge=1, le=90), business_id: int = Depends(owner_business),
                db=Depends(get_db)):
    return businesses.stats(db, business_id, days)
