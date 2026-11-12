"""Free time and bookings.

Time runs on a 30-minute grid. A slot is free when it lies inside the opening
hours of a working day, starts in the future and does not overlap another
active appointment of the same specialist.
"""
import threading
from datetime import date, datetime, timedelta

from . import clock
from .db import appointments, in_params

GRID = 30
FMT = clock.FMT
DAY_MINUTES = 24 * 60

# One booking at a time inside this process; PostgreSQL also locks the specialists' rows.
BOOKING_LOCK = threading.RLock()


class BookingError(Exception):
    """A booking rule was broken; the message is shown to the user."""


def parse_start(value: str) -> datetime:
    try:
        return datetime.strptime(value, FMT)
    except (TypeError, ValueError):
        raise BookingError("Неверный формат времени, нужен ГГГГ-ММ-ДДTЧЧ:ММ")


def _minutes(moment: datetime) -> int:
    return moment.hour * 60 + moment.minute


def working_days(business: dict) -> set[int]:
    return {int(d) for d in str(business["working_days"]).split(",") if d.strip() != ""}


# ------------------------------------------------------------------ offers

def load_offers(db, service_ids=None, business_id: int | None = None, specialist_id: int | None = None) -> list[dict]:
    """Every bookable combination of business, service and specialist."""
    sql = """
        SELECT b.id AS business_id, b.name AS business_name, b.category,
               b.open_hour, b.close_hour, b.working_days,
               s.id AS service_id, s.name AS service_name, s.price, s.duration_min,
               sp.id AS specialist_id, sp.name AS specialist_name, sp.title AS specialist_title
        FROM services s
        JOIN businesses b ON b.id = s.business_id
        JOIN specialist_services ss ON ss.service_id = s.id
        JOIN specialists sp ON sp.id = ss.specialist_id
        WHERE s.is_active = 1 AND b.is_active = 1 AND sp.is_active = 1
    """
    params: dict = {}
    if service_ids is not None:
        clause, params = in_params("svc", service_ids)
        sql += f" AND s.id IN {clause}"
    if business_id is not None:
        sql += " AND b.id = :business_id"
        params["business_id"] = business_id
    if specialist_id is not None:
        sql += " AND sp.id = :specialist_id"
        params["specialist_id"] = specialist_id
    sql += " ORDER BY b.id, s.sort_order, s.id, sp.sort_order, sp.id"
    offers = db.query(sql, **params)
    for offer in offers:
        offer["days"] = working_days(offer)
    return offers


def _busy(db, specialist_ids, first_day: date, last_day: date, exclude_id: int | None = None) -> dict:
    """Occupied intervals in minutes: {(specialist_id, "YYYY-MM-DD"): [(start, end), ...]}."""
    clause, params = in_params("sp", sorted(set(specialist_ids)))
    rows = db.query(
        f"""SELECT id, specialist_id, starts_at, duration_min FROM appointments
            WHERE specialist_id IN {clause} AND status != 'cancelled'
              AND starts_at >= :first AND starts_at < :last""",
        first=f"{first_day.isoformat()}T00:00",
        last=f"{(last_day + timedelta(days=1)).isoformat()}T00:00",
        **params,
    )
    busy: dict = {}
    for row in rows:
        if row["id"] == exclude_id:
            continue
        start = int(row["starts_at"][11:13]) * 60 + int(row["starts_at"][14:16])
        busy.setdefault((row["specialist_id"], row["starts_at"][:10]), []).append((start, start + row["duration_min"]))
    return busy


def _overlaps(intervals, start: int, end: int) -> bool:
    return any(start < busy_end and busy_start < end for busy_start, busy_end in intervals)


def _fits(offer: dict, day: date, minute: int, at: datetime) -> bool:
    """Is this start inside the opening hours and still in the future?"""
    if day.weekday() not in offer["days"]:
        return False
    if minute < offer["open_hour"] * 60 or minute + offer["duration_min"] > offer["close_hour"] * 60:
        return False
    return datetime(day.year, day.month, day.day) + timedelta(minutes=minute) > at


def _slot(offer: dict, day: date, minute: int) -> dict:
    start = datetime(day.year, day.month, day.day) + timedelta(minutes=minute)
    return {
        "business_id": offer["business_id"],
        "business_name": offer["business_name"],
        "category": offer["category"],
        "service_id": offer["service_id"],
        "service_name": offer["service_name"],
        "price": offer["price"],
        "duration_min": offer["duration_min"],
        "specialist_id": offer["specialist_id"],
        "specialist_name": offer["specialist_name"],
        "specialist_title": offer["specialist_title"],
        "start": start.strftime(FMT),
    }


def find_slots(
    db,
    offers: list[dict],
    day: date | None = None,
    from_min: int = 0,
    to_min: int = DAY_MINUTES,
    limit: int = 6,
    days_ahead: int = 14,
    spacing_min: int = 0,
    exclude_appointment_id: int | None = None,
) -> list[dict]:
    """Free slots for the offers, earliest first.

    One slot per (business, service, time): when several specialists are free,
    the first one is offered. With `spacing_min` the slots of one service are at
    least that far apart, which gives a varied choice in the chat; several
    services share the limit equally.
    """
    if not offers:
        return []
    at = clock.now()
    days = [day] if day else [at.date() + timedelta(days=i) for i in range(days_ahead)]
    days = [d for d in days if d >= at.date()]
    if not days:
        return []
    busy = _busy(db, [o["specialist_id"] for o in offers], days[0], days[-1], exclude_appointment_id)

    groups = {(o["business_id"], o["service_id"]) for o in offers}
    per_group = max(1, -(-limit // len(groups)))  # ceil
    taken: dict = {}  # group -> list of chosen starts
    result: list[dict] = []
    for d in days:
        day_key = d.isoformat()
        for minute in range(max(0, from_min) // GRID * GRID, min(to_min, DAY_MINUTES), GRID):
            if minute < from_min:
                continue
            for offer in offers:
                group = (offer["business_id"], offer["service_id"])
                chosen = taken.setdefault(group, [])
                if len(chosen) >= per_group or not _fits(offer, d, minute, at):
                    continue
                start = datetime(d.year, d.month, d.day) + timedelta(minutes=minute)
                if any(abs((start - other).total_seconds()) < max(spacing_min, 1) * 60 for other in chosen):
                    continue
                if _overlaps(busy.get((offer["specialist_id"], day_key), []), minute, minute + offer["duration_min"]):
                    continue
                chosen.append(start)
                result.append(_slot(offer, d, minute))
        if len(result) >= limit or all(len(taken.get(g, [])) >= per_group for g in groups):
            break
    result.sort(key=lambda s: (s["start"], s["business_id"]))
    return result[:limit]


# ------------------------------------------------------------ appointments

_APPOINTMENT_SQL = """
    SELECT a.id, a.business_id, b.name AS business_name, b.category, b.address AS business_address,
           a.service_id, s.name AS service_name, a.price, a.duration_min,
           a.specialist_id, sp.name AS specialist_name, sp.title AS specialist_title,
           a.starts_at, a.ends_at, a.status, a.source, a.note, a.customer_id,
           COALESCE(u.name, a.client_name) AS client_name,
           COALESCE(a.client_phone, u.phone) AS client_phone,
           r.rating AS review_rating, r.comment AS review_comment
    FROM appointments a
    JOIN businesses b ON b.id = a.business_id
    JOIN services s ON s.id = a.service_id
    JOIN specialists sp ON sp.id = a.specialist_id
    LEFT JOIN users u ON u.id = a.customer_id
    LEFT JOIN reviews r ON r.appointment_id = a.id
"""


def appointment_dict(row: dict, at: datetime | None = None) -> dict:
    moment = (at or clock.now()).strftime(FMT)
    ended = row["ends_at"] <= moment
    reviewed = row["review_rating"] is not None
    return {
        "id": row["id"],
        "business_id": row["business_id"],
        "business_name": row["business_name"],
        "category": row["category"],
        "address": row["business_address"],
        "service_id": row["service_id"],
        "service_name": row["service_name"],
        "price": row["price"],
        "duration_min": row["duration_min"],
        "specialist_id": row["specialist_id"],
        "specialist_name": row["specialist_name"],
        "specialist_title": row["specialist_title"],
        "start": row["starts_at"],
        "end": row["ends_at"],
        "status": row["status"],
        "source": row["source"],
        "note": row["note"] or "",
        "client_name": row["client_name"] or "",
        "client_phone": row["client_phone"] or "",
        "upcoming": row["status"] == "booked" and not ended,
        "can_review": row["customer_id"] is not None and ended and not reviewed
        and row["status"] in ("booked", "completed"),
        "review": {"rating": row["review_rating"], "comment": row["review_comment"] or ""} if reviewed else None,
    }


def get_appointment(db, appointment_id: int) -> dict | None:
    row = db.one(_APPOINTMENT_SQL + " WHERE a.id = :id", id=appointment_id)
    return appointment_dict(row) if row else None


def customer_appointments(db, customer_id: int, upcoming_only: bool = False) -> list[dict]:
    """A client's bookings, earliest first (the last 200 when history is included)."""
    sql = _APPOINTMENT_SQL + " WHERE a.customer_id = :customer_id"
    params: dict = {"customer_id": customer_id}
    if upcoming_only:
        sql += " AND a.status = 'booked' AND a.ends_at > :now ORDER BY a.starts_at, a.id"
        params["now"] = clock.stamp()
    else:
        sql += " ORDER BY a.starts_at DESC, a.id DESC LIMIT 200"
    rows = db.query(sql, **params)
    items = [appointment_dict(row) for row in rows]
    return items if upcoming_only else list(reversed(items))


def business_appointments(db, business_id: int, day: date) -> list[dict]:
    rows = db.query(
        _APPOINTMENT_SQL + " WHERE a.business_id = :b AND a.starts_at >= :first AND a.starts_at < :last"
        " ORDER BY a.starts_at, a.id",
        b=business_id,
        first=f"{day.isoformat()}T00:00",
        last=f"{(day + timedelta(days=1)).isoformat()}T00:00",
    )
    return [appointment_dict(row) for row in rows]


def _check_time(offer: dict, start: datetime) -> None:
    if start.minute % GRID != 0:
        raise BookingError("Запись возможна на :00 и :30")
    if start <= clock.now():
        raise BookingError("Это время уже прошло")
    if not _fits(offer, start.date(), _minutes(start), clock.now()):
        raise BookingError("В это время заведение не работает")


def _lock_specialists(tx, specialist_ids) -> None:
    """Serialise bookings of the same specialists across server processes."""
    if tx.dialect == "postgresql":
        clause, params = in_params("sp", sorted(set(specialist_ids)))
        tx.query(f"SELECT id FROM specialists WHERE id IN {clause} ORDER BY id FOR UPDATE", **params)


def _check_customer_free(tx, customer_id: int, start: str, end: str, exclude_id: int | None = None) -> None:
    rows = tx.query(
        """SELECT id FROM appointments
           WHERE customer_id = :c AND status != 'cancelled' AND starts_at < :end AND ends_at > :start""",
        c=customer_id, start=start, end=end,
    )
    if any(row["id"] != exclude_id for row in rows):
        raise BookingError("У вас уже есть запись на это время")


def book(
    db,
    *,
    service_id: int,
    start: str,
    customer_id: int | None = None,
    specialist_id: int | None = None,
    source: str = "app",
    client_name: str | None = None,
    client_phone: str | None = None,
    note: str = "",
) -> dict:
    """Create a booking. Without `specialist_id` the first free specialist is taken."""
    start_dt = parse_start(start)
    with BOOKING_LOCK, db.begin() as tx:
        offers = load_offers(tx, service_ids=[service_id])
        if not offers:
            raise BookingError("Услуга недоступна для записи")
        if specialist_id is not None:
            offers = [o for o in offers if o["specialist_id"] == specialist_id]
            if not offers:
                raise BookingError("Этот специалист не оказывает выбранную услугу")
        _check_time(offers[0], start_dt)
        _lock_specialists(tx, [o["specialist_id"] for o in offers])

        day, minute = start_dt.date(), _minutes(start_dt)
        busy = _busy(tx, [o["specialist_id"] for o in offers], day, day)
        free = [
            o for o in offers
            if not _overlaps(busy.get((o["specialist_id"], day.isoformat()), []), minute, minute + o["duration_min"])
        ]
        if not free:
            raise BookingError("Это время уже занято")
        offer = free[0]
        end = (start_dt + timedelta(minutes=offer["duration_min"])).strftime(FMT)
        if customer_id is not None:
            _check_customer_free(tx, customer_id, start, end)
        appointment_id = tx.insert(
            appointments,
            business_id=offer["business_id"],
            service_id=offer["service_id"],
            specialist_id=offer["specialist_id"],
            customer_id=customer_id,
            client_name=(client_name or "").strip() or None,
            client_phone=(client_phone or "").strip() or None,
            starts_at=start,
            ends_at=end,
            duration_min=offer["duration_min"],
            price=offer["price"],
            status="booked",
            source=source,
            note=(note or "").strip(),
            created_at=clock.stamp(),
        )
        return get_appointment(tx, appointment_id)


def _owned(tx, appointment_id: int, customer_id: int | None, business_id: int | None) -> dict:
    """Load an appointment the caller is allowed to change, or fail."""
    row = tx.one(
        """SELECT a.*, b.open_hour, b.close_hour, b.working_days
           FROM appointments a JOIN businesses b ON b.id = a.business_id WHERE a.id = :id""",
        id=appointment_id,
    )
    if row is None:
        raise BookingError("Запись не найдена")
    if customer_id is not None and row["customer_id"] != customer_id:
        raise BookingError("Запись не найдена")
    if business_id is not None and row["business_id"] != business_id:
        raise BookingError("Запись не найдена")
    return row


def reschedule(db, appointment_id: int, start: str, *, customer_id: int | None = None,
               business_id: int | None = None) -> dict:
    """Move a booking to another time with the same specialist."""
    start_dt = parse_start(start)
    with BOOKING_LOCK, db.begin() as tx:
        row = _owned(tx, appointment_id, customer_id, business_id)
        if row["status"] != "booked":
            raise BookingError("Перенести можно только активную запись")
        offer = {**row, "days": working_days(row)}
        _check_time(offer, start_dt)
        _lock_specialists(tx, [row["specialist_id"]])
        day, minute = start_dt.date(), _minutes(start_dt)
        busy = _busy(tx, [row["specialist_id"]], day, day, exclude_id=appointment_id)
        if _overlaps(busy.get((row["specialist_id"], day.isoformat()), []), minute, minute + row["duration_min"]):
            raise BookingError("Это время уже занято")
        end = (start_dt + timedelta(minutes=row["duration_min"])).strftime(FMT)
        if row["customer_id"] is not None:
            _check_customer_free(tx, row["customer_id"], start, end, exclude_id=appointment_id)
        tx.execute("UPDATE appointments SET starts_at = :s, ends_at = :e WHERE id = :id", s=start, e=end, id=appointment_id)
        return get_appointment(tx, appointment_id)


def cancel(db, appointment_id: int, *, customer_id: int | None = None, business_id: int | None = None) -> dict:
    """Cancel a booking. The record stays, with status `cancelled`."""
    with db.begin() as tx:
        row = _owned(tx, appointment_id, customer_id, business_id)
        if row["status"] != "booked":
            raise BookingError("Отменить можно только активную запись")
        tx.execute("UPDATE appointments SET status = 'cancelled' WHERE id = :id", id=appointment_id)
        return get_appointment(tx, appointment_id)


def set_status(db, appointment_id: int, status: str, *, business_id: int) -> dict:
    """Owner's action: mark a visit as completed, missed, cancelled or active again."""
    with BOOKING_LOCK, db.begin() as tx:
        row = _owned(tx, appointment_id, None, business_id)
        if status == "booked" and row["status"] == "cancelled":
            # Restoring a cancelled booking must not create an overlap.
            day = row["starts_at"][:10]
            minute = int(row["starts_at"][11:13]) * 60 + int(row["starts_at"][14:16])
            first = date.fromisoformat(day)
            busy = _busy(tx, [row["specialist_id"]], first, first, exclude_id=appointment_id)
            if _overlaps(busy.get((row["specialist_id"], day), []), minute, minute + row["duration_min"]):
                raise BookingError("Это время уже занято другой записью")
        tx.execute("UPDATE appointments SET status = :status WHERE id = :id", status=status, id=appointment_id)
        return get_appointment(tx, appointment_id)
