"""AI administrator: turns a client's free-form message into slots or actions.

Two engines behind one function, `answer()`:
- "ai": an OpenAI-compatible LLM with tool calling (set LLM_API_KEY);
- "rules": a data-driven matcher that works offline. It is used when no key is
  set or the LLM call fails, so the product always answers.

Both read services from the database, so whatever an owner adds can be booked
by chat right away.
"""
import json
import logging
import os
import re
from datetime import date, datetime, timedelta

import httpx

from . import businesses, clock, scheduling
from .catalog import CATEGORIES, CATEGORY_BY_ID, name_stems, normalize
from .db import in_params

log = logging.getLogger("assistant")

WEEKDAYS = [
    ["понедельник", "monday"],
    ["вторник", "tuesday"],
    ["среду", "среда", "среды", "wednesday"],
    ["четверг", "thursday"],
    ["пятниц", "friday"],
    ["суббот", "saturday"],
    ["воскресен", "sunday"],
]
MONTHS = {"янв": 1, "фев": 2, "мар": 3, "апр": 4, "мая": 5, "май": 5, "июн": 6,
          "июл": 7, "авг": 8, "сен": 9, "окт": 10, "ноя": 11, "дек": 12}
MONTHS_RU = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля",
             "августа", "сентября", "октября", "ноября", "декабря"]
WEEKDAYS_RU = ["пн", "вт", "ср", "чт", "пт", "сб", "вс"]
DAY_NAMES = ["пн", "вт", "ср", "чт", "пт", "сб", "вс"]

PARTS_OF_DAY = {
    "morning": (0, 12 * 60),
    "afternoon": (12 * 60, 17 * 60),
    "evening": (17 * 60, 24 * 60),
    "any": (0, 24 * 60),
}

CANCEL_WORDS = ["отмен", "отказ", "cancel"]
MOVE_WORDS = ["перенес", "перенос", "перезапи", "передвин", "reschedul"]
INFO_WORDS = ["адрес", "находит", "добраться", "график", "режим", "работает", "работаете",
              "телефон", "номер", "address", "hours", "phone", "location"]
BOOKING_WORDS = ["запис", "запиш", "прием", "время", "окно", "слот", "хочу", "нужн", "надо", "book", "appointment"]


# ------------------------------------------------------------ text helpers

def tokenize(text: str) -> list[str]:
    return re.findall(r"[a-zа-я0-9]+", text)


def hits(words: list[str], stems) -> int:
    """How many stems occur in the message. Short stems must equal a whole word."""
    count = 0
    for stem in stems:
        if len(stem) <= 3:
            count += stem in words
        else:
            count += any(word.startswith(stem) for word in words)
    return count


def money(amount: int) -> str:
    return "бесплатно" if amount == 0 else f"{amount:,}".replace(",", " ") + " сом"


def human_time(start: str) -> str:
    moment = datetime.strptime(start, scheduling.FMT)
    return f"{WEEKDAYS_RU[moment.weekday()]}, {moment.day} {MONTHS_RU[moment.month - 1]} в {moment:%H:%M}"


def human_day(day: date) -> str:
    return f"{day.day} {MONTHS_RU[day.month - 1]}"


_DATE_NUMERIC = re.compile(r"\b(\d{1,2})[./](\d{1,2})\b")
_DATE_WORDS = re.compile(r"\b(\d{1,2})\s+([а-я]{3,})")


def detect_date(text: str, words: list[str], today: date) -> tuple[date | None, str]:
    """Find a date in the message. Returns it with the text stripped of the date part."""
    if "послезавтра" in words:
        return today + timedelta(days=2), text
    if "завтра" in words or "tomorrow" in words:
        return today + timedelta(days=1), text
    if "сегодня" in words or "today" in words:
        return today, text

    def build(day: int, month: int) -> date | None:
        try:
            candidate = date(today.year, month, day)
        except ValueError:
            return None
        return candidate if candidate >= today else date(today.year + 1, month, day)

    match = _DATE_NUMERIC.search(text)
    if match:
        found = build(int(match.group(1)), int(match.group(2)))
        if found:
            return found, text.replace(match.group(0), " ")
    match = _DATE_WORDS.search(text)
    if match and match.group(2)[:3] in MONTHS:
        found = build(int(match.group(1)), MONTHS[match.group(2)[:3]])
        if found:
            return found, text.replace(match.group(0), " ")
    for weekday, stems in enumerate(WEEKDAYS):
        if hits(words, stems):
            return today + timedelta(days=(weekday - today.weekday()) % 7), text
    return None, text


_TIME_EXACT = re.compile(r"\b(\d{1,2}):(\d{2})\b")
_TIME_HOUR = re.compile(r"(?:^|\s)(?:в|на|к|at)\s+(\d{1,2})(?=\s|$|[,.!?])")


def detect_window(text: str, words: list[str]) -> tuple[int, int]:
    """The wanted time of day as minutes from midnight: [from, to)."""
    hour = minute = None
    match = _TIME_EXACT.search(text)
    if match:
        hour, minute = int(match.group(1)), int(match.group(2))
    else:
        match = _TIME_HOUR.search(text)
        if match:
            hour, minute = int(match.group(1)), 0
    if hour is not None and hour < 24 and minute < 60:
        if hour < 8 and not hits(words, ["утра", "утром", "am"]):  # "в 3" means 15:00
            hour += 12
        return hour * 60 + minute // scheduling.GRID * scheduling.GRID, 24 * 60
    if hits(words, ["утро", "утра", "утром", "morning"]):
        return PARTS_OF_DAY["morning"]
    if hits(words, ["вечер", "evening"]):
        return PARTS_OF_DAY["evening"]
    if "после обеда" in text or hits(words, ["днем", "обед", "afternoon"]):
        return PARTS_OF_DAY["afternoon"]
    return PARTS_OF_DAY["any"]


# ---------------------------------------------------------------- matching

_GENERIC = [stem for category in CATEGORIES for stem in category["keywords"]] + [
    stem for category in CATEGORIES for stem in name_stems(category["title"], drop_generic=False)
]


def _business_stems(name: str) -> list[str]:
    """Distinctive words of a business name ("Барбершоп Blade" -> blade)."""
    result = []
    for word in tokenize(normalize(name)):
        if len(word) < 3 or word in _GENERIC:
            continue
        # "барбершоп" only repeats the niche; "dentalux" is a name although it starts like one.
        if any(len(g) > 3 and (g.startswith(word) or (word.startswith(g) and len(word) - len(g) <= 3))
               for g in _GENERIC):
            continue
        result.append(word)
    return result


def _person_stems(name: str) -> list[str]:
    """Stems of a specialist's name that survive Russian case endings."""
    return [w[:-1] if len(w) > 4 else w for w in tokenize(normalize(name)) if len(w) >= 4]


def load_services(db, category: str | None = None, business_id: int | None = None) -> list[dict]:
    sql = """
        SELECT s.id, s.business_id, s.name, s.price, s.duration_min, s.keywords,
               b.name AS business_name, b.category, b.address, b.phone,
               b.open_hour, b.close_hour, b.working_days
        FROM services s JOIN businesses b ON b.id = s.business_id
        WHERE s.is_active = 1 AND b.is_active = 1
    """
    params: dict = {}
    if category:
        sql += " AND b.category = :category"
        params["category"] = category
    if business_id is not None:
        sql += " AND b.id = :business_id"
        params["business_id"] = business_id
    rows = db.query(sql + " ORDER BY b.id, s.sort_order, s.id", **params)
    for row in rows:
        row["stems"] = [k for k in row["keywords"].split(",") if k]
        row["business_stems"] = _business_stems(row["business_name"])
        row["category_stems"] = CATEGORY_BY_ID.get(row["category"], {}).get("keywords", [])
    return rows


def match_services(words: list[str], services: list[dict], limit: int = 3) -> list[dict]:
    """The best matching service of each business; only the top-scoring businesses stay."""
    best: dict = {}
    for service in services:
        score = (3 * hits(words, service["stems"])
                 + 2 * min(1, hits(words, service["business_stems"]))
                 + min(1, hits(words, service["category_stems"])))
        if score and score > best.get(service["business_id"], (0, None))[0]:
            best[service["business_id"]] = (score, service)
    if not best:
        return []
    top = max(score for score, _ in best.values())
    return [service for score, service in best.values() if score == top][:limit]


def load_specialists(db, business_ids) -> list[dict]:
    clause, params = in_params("b", sorted(set(business_ids)))
    rows = db.query(
        f"SELECT id, business_id, name, title FROM specialists WHERE is_active = 1 AND business_id IN {clause}"
        " ORDER BY business_id, sort_order, id",
        **params,
    )
    for row in rows:
        row["stems"] = _person_stems(row["name"])
    return rows


def match_specialists(words: list[str], specialists: list[dict]) -> list[dict]:
    return [sp for sp in specialists if sp["stems"] and hits(words, sp["stems"])]


def _first_service_of(db, specialist: dict, services: list[dict]) -> dict | None:
    performed = {
        row["service_id"]
        for row in db.query("SELECT service_id FROM specialist_services WHERE specialist_id = :s", s=specialist["id"])
    }
    return next((s for s in services if s["id"] in performed), None)


def pick_appointment(db, words: list[str], appointments: list[dict], day: date | None = None) -> dict | None:
    """Work out which of the client's bookings is meant; None when it is unclear."""
    if len(appointments) <= 1:
        return appointments[0] if appointments else None
    clause, params = in_params("svc", {a["service_id"] for a in appointments})
    keywords = {row["id"]: [k for k in row["keywords"].split(",") if k]
                for row in db.query(f"SELECT id, keywords FROM services WHERE id IN {clause}", **params)}

    def score(a: dict) -> int:
        return (3 * hits(words, keywords.get(a["service_id"], []))
                + 2 * min(1, hits(words, _business_stems(a["business_name"])))
                + 2 * min(1, hits(words, _person_stems(a["specialist_name"])))
                + min(1, hits(words, CATEGORY_BY_ID.get(a["category"], {}).get("keywords", []))))

    scores = [(score(a), a) for a in appointments]
    top = max(s for s, _ in scores)
    candidates = [a for s, a in scores if s == top] if top else appointments
    if len(candidates) > 1 and day is not None:
        candidates = [a for a in candidates if a["start"].startswith(day.isoformat())]
    return candidates[0] if len(candidates) == 1 else None


# -------------------------------------------------------------- rules mode

def _result(reply: str, slots: list | None = None, appointment: dict | None = None,
            reschedule_id: int | None = None, changed: bool = False) -> dict:
    return {
        "reply": reply,
        "slots": slots or [],
        "appointment": appointment,
        "reschedule_id": reschedule_id,
        "changed": changed,
    }


def _describe(a: dict) -> str:
    return f"{a['service_name']}, «{a['business_name']}» — {human_time(a['start'])}"


def _hours_text(business: dict) -> str:
    days = sorted(scheduling.working_days(business))
    if len(days) == 7:
        label = "ежедневно"
    elif days == list(range(days[0], days[-1] + 1)):
        label = f"{DAY_NAMES[days[0]]}–{DAY_NAMES[days[-1]]}"
    else:
        label = ", ".join(DAY_NAMES[d] for d in days)
    return f"{label}, {business['open_hour']:02d}:00–{business['close_hour']:02d}:00"


def _info_reply(service: dict) -> dict:
    parts = [f"«{service['business_name']}»"]
    if service["address"]:
        parts.append(f"адрес: {service['address']}")
    if service["phone"]:
        parts.append(f"телефон: {service['phone']}")
    parts.append(f"работаем {_hours_text(service)}")
    return _result("; ".join(parts) + ".")


def rules_reply(db, user: dict, message: str, category: str | None = None,
                business_id: int | None = None, specialist_id: int | None = None) -> dict:
    text = normalize(message)
    words = tokenize(text)
    day, rest = detect_date(text, words, clock.now().date())
    from_min, to_min = detect_window(rest, words)
    mine = scheduling.customer_appointments(db, user["id"], upcoming_only=True)
    listing = "\n".join(f"• {_describe(a)}" for a in mine)

    if hits(words, CANCEL_WORDS):
        if not mine:
            return _result("У вас нет активных записей.")
        target = pick_appointment(db, words, mine, day)
        if target is None:
            return _result("У вас несколько записей. Уточните, какую отменить, "
                           "например: «отмени запись на стрижку».\n" + listing)
        scheduling.cancel(db, target["id"], customer_id=user["id"])
        return _result(f"Отменил запись: {_describe(target)}.", changed=True)

    if hits(words, MOVE_WORDS):
        if not mine:
            return _result("У вас нет записей, которые можно перенести.")
        target = pick_appointment(db, words, mine)
        if target is None:
            return _result("У вас несколько записей. Уточните, какую перенести, "
                           "например: «перенеси стрижку на пятницу».\n" + listing)
        offers = [{
            **target,
            **db.one("SELECT open_hour, close_hour, working_days FROM businesses WHERE id = :id", id=target["business_id"]),
        }]
        offers[0]["days"] = scheduling.working_days(offers[0])
        find = dict(from_min=from_min, to_min=to_min, spacing_min=60, exclude_appointment_id=target["id"])
        slots = scheduling.find_slots(db, offers, day, **find)
        note = ""
        if not slots and day is not None:
            slots = scheduling.find_slots(db, offers, None, **find)
            note = f"На {human_day(day)} свободного времени нет. "
        slots = [s for s in slots if s["start"] != target["start"]]
        if not slots:
            return _result("К сожалению, у этого специалиста нет свободного времени в ближайшие две недели.")
        return _result(f"{note}Сейчас вы записаны: {_describe(target)}. Выберите новое время:",
                       slots=slots, reschedule_id=target["id"])

    if ("мои" in words and hits(words, ["запис"])) or ("my" in words and hits(words, ["appointment", "booking"])):
        if not mine:
            return _result("У вас пока нет записей. Напишите, куда и когда хотите записаться.")
        return _result("Ваши записи:\n" + listing)

    services = load_services(db, category, business_id)
    if not services:
        return _result("Пока здесь нет услуг для записи.")
    staff = load_specialists(db, {s["business_id"] for s in services})
    if specialist_id is not None:
        focus = [sp for sp in staff if sp["id"] == specialist_id]
    else:
        focus = match_specialists(words, staff)

    chosen = match_services(words, services)
    if focus:
        focus_businesses = {sp["business_id"] for sp in focus}
        narrowed = [s for s in chosen if s["business_id"] in focus_businesses]
        if narrowed:
            chosen = narrowed
        else:
            # Only a specialist was named: offer the first service they perform.
            chosen = [s for s in (_first_service_of(db, sp, services) for sp in focus) if s][:3]
    if not chosen and business_id is not None and hits(words, INFO_WORDS):
        return _info_reply(services[0])
    if len(chosen) == 1 and hits(words, INFO_WORDS) and not hits(words, chosen[0]["stems"]):
        return _info_reply(chosen[0])

    if not chosen:
        if business_id is not None:
            price_list = "\n".join(f"• {s['name']} — {money(s['price'])}, {s['duration_min']} мин" for s in services)
            return _result(f"Я ИИ-администратор «{services[0]['business_name']}». На какую услугу вас записать?\n{price_list}")
        if day is not None or hits(words, BOOKING_WORDS):
            return _result("Подскажите, на какую услугу вас записать? Например: стрижка, маникюр, "
                           "чистка зубов, массаж или замена масла.")
        return _result(
            f"Здравствуйте, {user['name']}! Я ИИ-администратор Smile AI. Запишу к стоматологу, в барбершоп, "
            "салон красоты, автосервис и не только. Напишите, что нужно и когда удобно, например: "
            "«болит зуб, завтра после обеда», «стрижка в субботу утром» или «замена масла в пятницу»."
        )

    offers = scheduling.load_offers(db, service_ids=[s["id"] for s in chosen])
    if focus:
        focus_ids = {sp["id"] for sp in focus}
        offers = [o for o in offers if o["specialist_id"] in focus_ids] or offers
    find = dict(from_min=from_min, to_min=to_min, spacing_min=60)
    slots = scheduling.find_slots(db, offers, day, **find)
    note = ""
    if not slots and day is not None:
        slots = scheduling.find_slots(db, offers, None, **find)
        note = f"На {human_day(day)} свободного времени нет. Ближайшие варианты. "
    if not slots:
        return _result("К сожалению, свободного времени в ближайшие две недели нет.")

    if len(chosen) == 1:
        s = chosen[0]
        found = f"«{s['name']}» в «{s['business_name']}» — {money(s['price'])}, {s['duration_min']} мин."
    else:
        options = "; ".join(f"«{s['business_name']}» — {s['name'].lower()}, {money(s['price'])}" for s in chosen)
        found = f"Нашёл несколько мест: {options}."
    return _result(f"{note}{found} Выберите время:", slots=slots)


# ------------------------------------------------------------------- AI mode

TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "search_services",
            "description": "Find services by what the client asked for. Returns services with business, price and duration.",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {"type": "string", "description": "What the client wants, in their words"},
                    "category": {"type": "string", "enum": [*CATEGORY_BY_ID, "any"]},
                },
                "required": ["query"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "find_slots",
            "description": "Find free time for a service. Call before suggesting any time; the app shows the result as tappable cards.",
            "parameters": {
                "type": "object",
                "properties": {
                    "service_id": {"type": "integer"},
                    "specialist_id": {"type": "integer", "description": "Limit to one specialist (optional)"},
                    "date": {"type": "string", "description": "YYYY-MM-DD, or empty for the nearest days"},
                    "part_of_day": {"type": "string", "enum": ["morning", "afternoon", "evening", "any"]},
                    "reschedule_appointment_id": {
                        "type": "integer",
                        "description": "Set when the slots are offered to move this existing booking",
                    },
                },
                "required": ["service_id"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "book_appointment",
            "description": "Book a slot. Only after the client explicitly confirmed service and time.",
            "parameters": {
                "type": "object",
                "properties": {
                    "service_id": {"type": "integer"},
                    "specialist_id": {"type": "integer"},
                    "start": {"type": "string", "description": "YYYY-MM-DDTHH:MM"},
                },
                "required": ["service_id", "start"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "list_my_appointments",
            "description": "List the client's upcoming bookings with their ids.",
            "parameters": {"type": "object", "properties": {}},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "cancel_appointment",
            "description": "Cancel a booking. Only after the client clearly asked to cancel this one.",
            "parameters": {
                "type": "object",
                "properties": {"appointment_id": {"type": "integer"}},
                "required": ["appointment_id"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "reschedule_appointment",
            "description": "Move a booking to a new time with the same specialist, after explicit confirmation.",
            "parameters": {
                "type": "object",
                "properties": {
                    "appointment_id": {"type": "integer"},
                    "start": {"type": "string", "description": "YYYY-MM-DDTHH:MM"},
                },
                "required": ["appointment_id", "start"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "business_info",
            "description": "Address, phone, opening hours, services and specialists of a business.",
            "parameters": {
                "type": "object",
                "properties": {"business_id": {"type": "integer"}},
                "required": ["business_id"],
            },
        },
    },
]


def system_prompt(db, user: dict, category: str | None = None, business_id: int | None = None,
                  specialist_id: int | None = None) -> str:
    at = clock.now()
    niches = ", ".join(f"{c['title']} ({c['id']})" for c in CATEGORIES)
    scope = ""
    if business_id is not None:
        business = businesses.get_business(db, business_id)
        if business:
            lines = "\n".join(
                f"  - service_id={s['id']} {s['name']}: {s['price']} som, {s['duration_min']} min" for s in business["services"]
            )
            staff = ", ".join(f"id={sp['id']} {sp['name']} ({sp['title']})" for sp in business["specialists"])
            scope = (f"You are the administrator of «{business['name']}» (business_id={business['id']}), "
                     f"{business['address']}. Only offer this business.\nServices:\n{lines}\nSpecialists: {staff}\n")
    elif category:
        scope = f"The client is browsing the '{category}' niche; prefer it.\n"
    if specialist_id is not None:
        scope += f"The client asked about the specialist with id={specialist_id}; search slots with this specialist_id.\n"
    return (
        "You are the AI administrator of Smile AI, a booking service for local businesses in Bishkek. "
        f"Client name: {user['name']}. Now: {at:%Y-%m-%d %H:%M} ({at:%A}), timezone Asia/Bishkek.\n"
        f"Niches: {niches}.\n{scope}"
        "Rules: reply in the client's language (default Russian), at most 3 short sentences, friendly. "
        "Use search_services to find what the client needs, then find_slots before offering any time; "
        "never invent services, prices or times. The app shows found slots as tappable cards, so do not "
        "list every slot in text. Book, cancel or reschedule only after explicit confirmation. "
        "To move a booking, call list_my_appointments, then find_slots with reschedule_appointment_id. "
        "You do not give medical diagnoses."
    )


def run_tool(db, user: dict, name: str, args: dict, state: dict, category: str | None, business_id: int | None) -> str:
    def dump(value) -> str:
        return json.dumps(value, ensure_ascii=False)

    try:
        if name == "search_services":
            wanted = args.get("category")
            scope = wanted if wanted in CATEGORY_BY_ID else category
            services = load_services(db, None if business_id is not None else scope, business_id)
            found = match_services(tokenize(normalize(str(args.get("query", "")))), services, limit=5)
            if not found and business_id is not None:
                found = services
            return dump([
                {"service_id": s["id"], "service": s["name"], "business_id": s["business_id"],
                 "business": s["business_name"], "category": s["category"], "price": s["price"],
                 "duration_min": s["duration_min"]}
                for s in found
            ])
        if name == "find_slots":
            specialist = int(args["specialist_id"]) if args.get("specialist_id") else None
            offers = scheduling.load_offers(db, service_ids=[int(args["service_id"])], specialist_id=specialist)
            day = None
            if args.get("date"):
                try:
                    day = datetime.strptime(args["date"], "%Y-%m-%d").date()
                except ValueError:
                    day = None
            from_min, to_min = PARTS_OF_DAY.get(args.get("part_of_day", "any"), PARTS_OF_DAY["any"])
            moving = int(args["reschedule_appointment_id"]) if args.get("reschedule_appointment_id") else None
            slots = scheduling.find_slots(db, offers, day, from_min=from_min, to_min=to_min, spacing_min=60,
                                          exclude_appointment_id=moving)
            state["slots"] = slots
            state["reschedule_id"] = moving
            return dump(slots)
        if name == "business_info":
            return dump(businesses.get_business(db, int(args["business_id"])) or {"error": "not found"})
        if name == "list_my_appointments":
            return dump(scheduling.customer_appointments(db, user["id"], upcoming_only=True))
        if name == "book_appointment":
            specialist = int(args["specialist_id"]) if args.get("specialist_id") else None
            appointment = scheduling.book(db, service_id=int(args["service_id"]), start=str(args["start"]),
                                          customer_id=user["id"], specialist_id=specialist, source="chat")
        elif name == "reschedule_appointment":
            appointment = scheduling.reschedule(db, int(args["appointment_id"]), str(args["start"]),
                                                customer_id=user["id"])
        elif name == "cancel_appointment":
            cancelled = scheduling.cancel(db, int(args["appointment_id"]), customer_id=user["id"])
            state.update(slots=[], reschedule_id=None, changed=True)
            return dump({"cancelled": cancelled})
        else:
            return dump({"error": f"unknown tool {name}"})
    except (scheduling.BookingError, KeyError, ValueError, TypeError) as e:
        return dump({"error": str(e)})
    # booked or rescheduled
    state.update(appointment=appointment, slots=[], reschedule_id=None, changed=True)
    return dump(appointment)


def ai_reply(db, user: dict, message: str, history: list[dict], category: str | None = None,
             business_id: int | None = None, specialist_id: int | None = None) -> dict:
    api_key = os.environ["LLM_API_KEY"]
    base_url = os.getenv("LLM_BASE_URL", "https://api.openai.com/v1").rstrip("/")
    model = os.getenv("LLM_MODEL", "gpt-4o-mini")

    messages = [{"role": "system", "content": system_prompt(db, user, category, business_id, specialist_id)}]
    for item in history[-10:]:
        role = "assistant" if item.get("role") == "assistant" else "user"
        messages.append({"role": role, "content": str(item.get("text", ""))})
    messages.append({"role": "user", "content": message})

    state: dict = {"slots": [], "appointment": None, "reschedule_id": None, "changed": False}
    with httpx.Client(timeout=40) as client:
        for _ in range(8):
            response = client.post(
                f"{base_url}/chat/completions",
                headers={"Authorization": f"Bearer {api_key}"},
                json={"model": model, "messages": messages, "tools": TOOLS, "temperature": 0.3},
            )
            response.raise_for_status()
            reply = response.json()["choices"][0]["message"]
            calls = reply.get("tool_calls") or []
            if not calls:
                return _result(
                    (reply.get("content") or "").strip() or "Готово.",
                    slots=state["slots"],
                    appointment=state["appointment"],
                    reschedule_id=state["reschedule_id"] if state["slots"] else None,
                    changed=state["changed"],
                )
            messages.append({"role": "assistant", "content": reply.get("content"), "tool_calls": calls})
            for call in calls:
                try:
                    args = json.loads(call["function"].get("arguments") or "{}")
                except json.JSONDecodeError:
                    args = {}
                output = run_tool(db, user, call["function"]["name"], args, state, category, business_id)
                messages.append({"role": "tool", "tool_call_id": call["id"], "content": output})
    raise RuntimeError("LLM did not finish in 8 steps")


def answer(db, user: dict, message: str, history: list[dict], category: str | None = None,
           business_id: int | None = None, specialist_id: int | None = None) -> dict:
    if category not in CATEGORY_BY_ID:
        category = None
    if os.getenv("LLM_API_KEY"):
        try:
            return {**ai_reply(db, user, message, history, category, business_id, specialist_id), "mode": "ai"}
        except Exception as e:  # network, quota, bad response -> keep the product answering
            log.warning("LLM failed, falling back to rules: %s", e)
    return {**rules_reply(db, user, message, category, business_id, specialist_id), "mode": "rules"}
