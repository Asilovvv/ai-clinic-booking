"""Clinic schedule: working hours, free slots and booking rules."""
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

from .db import Database

TZ = ZoneInfo("Asia/Bishkek")
OPEN_HOUR = 9
CLOSE_HOUR = 18  # last slot starts at 17:00
WORKING_WEEKDAYS = {0, 1, 2, 3, 4, 5}  # Mon-Sat
FMT = "%Y-%m-%dT%H:%M"


def now() -> datetime:
    return datetime.now(TZ).replace(tzinfo=None, second=0, microsecond=0)


def doctor_dict(row: dict) -> dict:
    return {
        "id": row["id"],
        "name": row["name"],
        "specialty": row["specialty"],
        "title": row["title"],
        "description": row["description"],
    }


def list_doctors(db: Database, specialty: str | None = None) -> list[dict]:
    if specialty:
        rows = db.query("SELECT * FROM doctors WHERE specialty = ? ORDER BY id", (specialty,))
    else:
        rows = db.query("SELECT * FROM doctors ORDER BY id")
    return [doctor_dict(r) for r in rows]


def is_valid_slot(start: datetime) -> bool:
    return (
        start.weekday() in WORKING_WEEKDAYS
        and OPEN_HOUR <= start.hour < CLOSE_HOUR
        and start.minute == 0
        and start > now()
    )


def find_slots(
    db: Database,
    doctor_ids: list[int] | None = None,
    day: date | None = None,
    hour_from: int = OPEN_HOUR,
    hour_to: int = CLOSE_HOUR,
    limit: int = 6,
    days_ahead: int = 14,
) -> list[dict]:
    """Return free one-hour slots, earliest first, spread across doctors."""
    doctors = list_doctors(db)
    if doctor_ids:
        doctors = [d for d in doctors if d["id"] in doctor_ids]
    booked = {(r["doctor_id"], r["start"]) for r in db.query("SELECT doctor_id, start FROM appointments")}

    days = [day] if day else [now().date() + timedelta(days=i) for i in range(days_ahead)]
    result: list[dict] = []
    for d in days:
        for hour in range(max(hour_from, OPEN_HOUR), min(hour_to, CLOSE_HOUR)):
            start = datetime(d.year, d.month, d.day, hour)
            if not is_valid_slot(start):
                continue
            for doc in doctors:
                key = (doc["id"], start.strftime(FMT))
                if key in booked:
                    continue
                result.append(
                    {
                        "doctor_id": doc["id"],
                        "doctor_name": doc["name"],
                        "doctor_title": doc["title"],
                        "start": start.strftime(FMT),
                    }
                )
                if len(result) >= limit:
                    return result
    return result


def appointment_dict(row: dict) -> dict:
    return {
        "id": row["id"],
        "doctor_id": row["doctor_id"],
        "doctor_name": row["doctor_name"],
        "doctor_title": row["doctor_title"],
        "start": row["start"],
    }


def user_appointments(db: Database, user_id: int) -> list[dict]:
    rows = db.query(
        """SELECT a.id, a.doctor_id, a.start, d.name AS doctor_name, d.title AS doctor_title
           FROM appointments a JOIN doctors d ON d.id = a.doctor_id
           WHERE a.user_id = ? AND a.start >= ? ORDER BY a.start""",
        (user_id, now().strftime(FMT)),
    )
    return [appointment_dict(r) for r in rows]


class BookingError(Exception):
    pass


def book(db: Database, user_id: int, doctor_id: int, start_str: str) -> dict:
    try:
        start = datetime.strptime(start_str, FMT)
    except ValueError:
        raise BookingError("Неверный формат времени, нужен YYYY-MM-DDTHH:MM")
    if db.one("SELECT id FROM doctors WHERE id = ?", (doctor_id,)) is None:
        raise BookingError("Врач не найден")
    if not is_valid_slot(start):
        raise BookingError("Клиника не работает в это время или время уже прошло")
    if db.one("SELECT id FROM appointments WHERE doctor_id = ? AND start = ?", (doctor_id, start_str)):
        raise BookingError("Это время уже занято")
    if db.one("SELECT id FROM appointments WHERE user_id = ? AND start = ?", (user_id, start_str)):
        raise BookingError("У вас уже есть запись на это время")
    appt_id = db.execute(
        "INSERT INTO appointments (user_id, doctor_id, start) VALUES (?, ?, ?)",
        (user_id, doctor_id, start_str),
    )
    row = db.one(
        """SELECT a.id, a.doctor_id, a.start, d.name AS doctor_name, d.title AS doctor_title
           FROM appointments a JOIN doctors d ON d.id = a.doctor_id WHERE a.id = ?""",
        (appt_id,),
    )
    return appointment_dict(row)
