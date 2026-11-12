"""Businesses: the public catalog, the owner's management actions and statistics."""
from datetime import timedelta

from . import clock, scheduling
from .catalog import CATEGORY_BY_ID, DURATIONS, normalize, service_keywords
from .db import businesses, in_params, reviews, services, specialist_services, specialists


class BusinessError(Exception):
    """An owner's request cannot be carried out; the message is shown to the user."""


# ----------------------------------------------------------------- reading

def _ratings(db, business_ids) -> dict:
    clause, params = in_params("b", business_ids)
    rows = db.query(
        f"SELECT business_id, AVG(rating) AS rating, COUNT(*) AS n FROM reviews"
        f" WHERE business_id IN {clause} GROUP BY business_id",
        **params,
    )
    return {row["business_id"]: (round(float(row["rating"]), 1), int(row["n"])) for row in rows}


def _business_dict(row: dict, service_rows: list[dict], rating: tuple | None) -> dict:
    category = CATEGORY_BY_ID.get(row["category"], {})
    prices = [s["price"] for s in service_rows]
    search = " ".join([row["name"], row["address"], row["description"], category.get("title", "")]
                      + [s["name"] for s in service_rows])
    return {
        "id": row["id"],
        "category": row["category"],
        "name": row["name"],
        "description": row["description"],
        "address": row["address"],
        "phone": row["phone"],
        "open_hour": row["open_hour"],
        "close_hour": row["close_hour"],
        "working_days": sorted(scheduling.working_days(row)),
        "is_active": bool(row["is_active"]),
        "rating": rating[0] if rating else None,
        "reviews_count": rating[1] if rating else 0,
        "price_from": min(prices) if prices else None,
        "services_count": len(service_rows),
        "search_text": normalize(search),
    }


def list_businesses(db, category: str | None = None) -> list[dict]:
    """Active businesses for the catalog, best rated first."""
    sql, params = "SELECT * FROM businesses WHERE is_active = 1", {}
    if category:
        sql += " AND category = :category"
        params["category"] = category
    rows = db.query(sql + " ORDER BY id", **params)
    ids = [row["id"] for row in rows]
    clause, id_params = in_params("b", ids)
    by_business: dict = {}
    for service in db.query(
        f"SELECT business_id, name, price FROM services WHERE is_active = 1 AND business_id IN {clause}"
        " ORDER BY sort_order, id",
        **id_params,
    ):
        by_business.setdefault(service["business_id"], []).append(service)
    ratings = _ratings(db, ids)
    result = [_business_dict(row, by_business.get(row["id"], []), ratings.get(row["id"])) for row in rows]
    result.sort(key=lambda b: (-(b["rating"] or 0), -b["reviews_count"], b["id"]))
    return result


def get_business(db, business_id: int, only_active: bool = True) -> dict | None:
    """One business with its services, specialists and latest reviews."""
    row = db.one("SELECT * FROM businesses WHERE id = :id", id=business_id)
    if row is None or (only_active and not row["is_active"]):
        return None
    service_rows = db.query(
        "SELECT * FROM services WHERE business_id = :b AND is_active = 1 ORDER BY sort_order, id", b=business_id
    )
    staff_rows = db.query(
        "SELECT * FROM specialists WHERE business_id = :b AND is_active = 1 ORDER BY sort_order, id", b=business_id
    )
    staff_ids = {s["id"] for s in staff_rows}
    clause, params = in_params("svc", [s["id"] for s in service_rows])
    performers: dict = {}
    for link in db.query(f"SELECT specialist_id, service_id FROM specialist_services WHERE service_id IN {clause}", **params):
        if link["specialist_id"] in staff_ids:
            performers.setdefault(link["service_id"], []).append(link["specialist_id"])
    review_rows = db.query(
        """SELECT r.rating, r.comment, r.created_at, u.name AS author
           FROM reviews r JOIN users u ON u.id = r.customer_id
           WHERE r.business_id = :b ORDER BY r.created_at DESC, r.id DESC LIMIT 10""",
        b=business_id,
    )
    result = _business_dict(row, service_rows, _ratings(db, [business_id]).get(business_id))
    result["services"] = [
        {
            "id": s["id"],
            "name": s["name"],
            "description": s["description"],
            "duration_min": s["duration_min"],
            "price": s["price"],
            "specialist_ids": sorted(performers.get(s["id"], [])),
        }
        for s in service_rows
    ]
    result["specialists"] = [{"id": s["id"], "name": s["name"], "title": s["title"]} for s in staff_rows]
    result["reviews"] = review_rows
    return result


def owner_business_id(db, owner_id: int) -> int | None:
    row = db.one("SELECT id FROM businesses WHERE owner_id = :o ORDER BY id LIMIT 1", o=owner_id)
    return row["id"] if row else None


# ----------------------------------------------------------- owner actions

def _check_hours(open_hour: int, close_hour: int, days) -> str:
    if not 0 <= open_hour < close_hour <= 24:
        raise BusinessError("Время закрытия должно быть позже времени открытия")
    days = sorted({int(d) for d in days})
    if not days or any(d < 0 or d > 6 for d in days):
        raise BusinessError("Выберите хотя бы один рабочий день")
    return ",".join(str(d) for d in days)


def create_business(db, owner: dict, data: dict) -> dict:
    """Create the owner's business; with `use_template` the niche's typical services are added."""
    category = CATEGORY_BY_ID.get(data["category"])
    if category is None:
        raise BusinessError("Неизвестная ниша")
    days = _check_hours(data["open_hour"], data["close_hour"], data["working_days"])
    with db.begin() as tx:
        if owner_business_id(tx, owner["id"]) is not None:
            raise BusinessError("У этого аккаунта уже есть бизнес")
        business_id = tx.insert(
            businesses,
            owner_id=owner["id"],
            category=category["id"],
            name=data["name"].strip(),
            description=data.get("description", "").strip(),
            address=data.get("address", "").strip(),
            phone=data.get("phone", "").strip(),
            open_hour=data["open_hour"],
            close_hour=data["close_hour"],
            working_days=days,
            is_active=1,
            created_at=clock.stamp(),
        )
        # The owner is the first specialist; more can be added later.
        specialist_id = tx.insert(
            specialists, business_id=business_id, name=owner["name"], title=category["specialist_title"],
            is_active=1, sort_order=0,
        )
        if data.get("use_template", True):
            for order, (name, duration, price, keywords) in enumerate(category["services"]):
                service_id = tx.insert(
                    services, business_id=business_id, name=name, description="", duration_min=duration,
                    price=price, keywords=service_keywords(name, keywords), is_active=1, sort_order=order,
                )
                tx.insert(specialist_services, specialist_id=specialist_id, service_id=service_id)
        return get_business(tx, business_id, only_active=False)


def update_business(db, business_id: int, changes: dict) -> dict:
    current = db.one("SELECT * FROM businesses WHERE id = :id", id=business_id)
    values = {}
    for field in ("name", "description", "address", "phone"):
        if changes.get(field) is not None:
            values[field] = changes[field].strip()
    if "name" in values and len(values["name"]) < 2:
        raise BusinessError("Введите название")
    if any(changes.get(f) is not None for f in ("open_hour", "close_hour", "working_days")):
        open_hour = changes["open_hour"] if changes.get("open_hour") is not None else current["open_hour"]
        close_hour = changes["close_hour"] if changes.get("close_hour") is not None else current["close_hour"]
        days = changes["working_days"] if changes.get("working_days") is not None else scheduling.working_days(current)
        values.update(open_hour=open_hour, close_hour=close_hour, working_days=_check_hours(open_hour, close_hour, days))
    if changes.get("is_active") is not None:
        values["is_active"] = 1 if changes["is_active"] else 0
    if values:
        assignments = ", ".join(f"{field} = :{field}" for field in values)
        db.execute(f"UPDATE businesses SET {assignments} WHERE id = :id", id=business_id, **values)
    return get_business(db, business_id, only_active=False)


def _own_ids(tx, table: str, business_id: int) -> set[int]:
    return {row["id"] for row in tx.query(f"SELECT id FROM {table} WHERE business_id = :b AND is_active = 1", b=business_id)}


def save_service(db, business_id: int, data: dict, service_id: int | None = None) -> dict:
    """Add a service or change one. `specialist_ids=None` means every specialist performs it."""
    if data["duration_min"] not in DURATIONS:
        raise BusinessError("Длительность: 30, 60, 90, 120, 150 или 180 минут")
    with db.begin() as tx:
        staff = _own_ids(tx, "specialists", business_id)
        chosen = staff if data.get("specialist_ids") is None else set(data["specialist_ids"]) & staff
        if not chosen:
            raise BusinessError("Выберите, кто выполняет услугу")
        values = dict(
            name=data["name"].strip(),
            description=data.get("description", "").strip(),
            duration_min=data["duration_min"],
            price=data["price"],
        )
        if service_id is None:
            order = tx.one("SELECT COUNT(*) AS n FROM services WHERE business_id = :b", b=business_id)["n"]
            service_id = tx.insert(
                services, business_id=business_id, keywords=service_keywords(values["name"]),
                is_active=1, sort_order=int(order), **values,
            )
        else:
            current = tx.one("SELECT * FROM services WHERE id = :id AND business_id = :b AND is_active = 1",
                             id=service_id, b=business_id)
            if current is None:
                raise BusinessError("Услуга не найдена")
            if normalize(current["name"]) != normalize(values["name"]):
                values["keywords"] = service_keywords(values["name"])  # renamed: refresh what the assistant matches
            assignments = ", ".join(f"{field} = :{field}" for field in values)
            tx.execute(f"UPDATE services SET {assignments} WHERE id = :id", id=service_id, **values)
            tx.execute("DELETE FROM specialist_services WHERE service_id = :id", id=service_id)
        for specialist_id in sorted(chosen):
            tx.insert(specialist_services, specialist_id=specialist_id, service_id=service_id)
        return get_business(tx, business_id, only_active=False)


def delete_service(db, business_id: int, service_id: int) -> dict:
    """Hide a service. Existing bookings keep it."""
    with db.begin() as tx:
        if service_id not in _own_ids(tx, "services", business_id):
            raise BusinessError("Услуга не найдена")
        tx.execute("UPDATE services SET is_active = 0 WHERE id = :id", id=service_id)
        return get_business(tx, business_id, only_active=False)


def save_specialist(db, business_id: int, data: dict, specialist_id: int | None = None) -> dict:
    """Add a specialist (who then performs every service unless `service_ids` is given) or rename one."""
    with db.begin() as tx:
        if specialist_id is None:
            order = tx.one("SELECT COUNT(*) AS n FROM specialists WHERE business_id = :b", b=business_id)["n"]
            specialist_id = tx.insert(
                specialists, business_id=business_id, name=data["name"].strip(), title=data.get("title", "").strip(),
                is_active=1, sort_order=int(order),
            )
            own_services = _own_ids(tx, "services", business_id)
            wanted = own_services if data.get("service_ids") is None else set(data["service_ids"]) & own_services
            for service_id in sorted(wanted):
                tx.insert(specialist_services, specialist_id=specialist_id, service_id=service_id)
        else:
            if specialist_id not in _own_ids(tx, "specialists", business_id):
                raise BusinessError("Специалист не найден")
            tx.execute("UPDATE specialists SET name = :name, title = :title WHERE id = :id",
                       name=data["name"].strip(), title=data.get("title", "").strip(), id=specialist_id)
        return get_business(tx, business_id, only_active=False)


def delete_specialist(db, business_id: int, specialist_id: int) -> dict:
    with db.begin() as tx:
        staff = _own_ids(tx, "specialists", business_id)
        if specialist_id not in staff:
            raise BusinessError("Специалист не найден")
        if len(staff) == 1:
            raise BusinessError("Нельзя удалить единственного специалиста")
        future = tx.one(
            "SELECT COUNT(*) AS n FROM appointments WHERE specialist_id = :s AND status = 'booked' AND starts_at > :now",
            s=specialist_id, now=clock.stamp(),
        )
        if future["n"]:
            raise BusinessError("У специалиста есть будущие записи. Сначала перенесите или отмените их")
        tx.execute("UPDATE specialists SET is_active = 0 WHERE id = :id", id=specialist_id)
        return get_business(tx, business_id, only_active=False)


# -------------------------------------------------------------- statistics

def add_review(db, customer_id: int, appointment_id: int, rating: int, comment: str) -> dict:
    """A client rates a finished visit, once."""
    appointment = scheduling.get_appointment(db, appointment_id)
    row = db.one("SELECT customer_id FROM appointments WHERE id = :id", id=appointment_id)
    if appointment is None or row["customer_id"] != customer_id:
        raise BusinessError("Запись не найдена")
    if not appointment["can_review"]:
        raise BusinessError("Оценить можно завершённый визит, один раз")
    db.insert(
        reviews, appointment_id=appointment_id, business_id=appointment["business_id"], customer_id=customer_id,
        rating=rating, comment=comment.strip(), created_at=clock.stamp(),
    )
    return scheduling.get_appointment(db, appointment_id)


def stats(db, business_id: int, days: int = 7) -> dict:
    """Numbers for the owner's dashboard: today, the last `days` days and what is ahead."""
    at = clock.now()
    today = at.date()
    first = today - timedelta(days=days - 1)
    rows = db.query(
        """SELECT a.starts_at, a.status, a.source, a.price, a.duration_min, a.customer_id, a.client_name,
                  a.service_id, s.name AS service_name
           FROM appointments a JOIN services s ON s.id = a.service_id
           WHERE a.business_id = :b AND a.starts_at >= :first AND a.starts_at < :last""",
        b=business_id, first=f"{first.isoformat()}T00:00", last=f"{(today + timedelta(days=1)).isoformat()}T00:00",
    )
    kept = [r for r in rows if r["status"] != "cancelled"]
    earning = [r for r in kept if r["status"] != "no_show"]
    today_key = today.isoformat()

    by_day = []
    for offset in range(days):
        key = (first + timedelta(days=offset)).isoformat()
        day_rows = [r for r in earning if r["starts_at"].startswith(key)]
        by_day.append({"date": key, "count": len(day_rows), "revenue": sum(r["price"] for r in day_rows)})

    top: dict = {}
    for r in earning:
        entry = top.setdefault(r["service_id"], {"name": r["service_name"], "count": 0, "revenue": 0})
        entry["count"] += 1
        entry["revenue"] += r["price"]

    business = db.one("SELECT * FROM businesses WHERE id = :id", id=business_id)
    staff = db.one("SELECT COUNT(*) AS n FROM specialists WHERE business_id = :b AND is_active = 1", b=business_id)["n"]
    capacity = 0
    if today.weekday() in scheduling.working_days(business):
        capacity = int(staff) * (business["close_hour"] - business["open_hour"]) * 60
    today_rows = [r for r in kept if r["starts_at"].startswith(today_key)]
    booked_minutes = sum(r["duration_min"] for r in today_rows)

    upcoming = db.one(
        "SELECT COUNT(*) AS n FROM appointments WHERE business_id = :b AND status = 'booked' AND starts_at > :now",
        b=business_id, now=at.strftime(clock.FMT),
    )["n"]
    rating = _ratings(db, [business_id]).get(business_id)
    clients = {r["customer_id"] or r["client_name"] for r in kept}
    return {
        "days": days,
        "today_count": len(today_rows),
        "today_revenue": sum(r["price"] for r in today_rows if r["status"] != "no_show"),
        "load_percent": round(100 * booked_minutes / capacity) if capacity else 0,
        "upcoming": int(upcoming),
        "bookings": len(kept),
        "revenue": sum(r["price"] for r in earning),
        "completed": sum(1 for r in rows if r["status"] == "completed"),
        "cancelled": sum(1 for r in rows if r["status"] == "cancelled"),
        "no_show": sum(1 for r in rows if r["status"] == "no_show"),
        "ai_bookings": sum(1 for r in kept if r["source"] == "chat"),
        "clients": len(clients),
        "rating": rating[0] if rating else None,
        "reviews_count": rating[1] if rating else 0,
        "by_day": by_day,
        "top_services": sorted(top.values(), key=lambda e: (-e["count"], e["name"]))[:3],
        "today": scheduling.business_appointments(db, business_id, today),
    }
