"""AI booking assistant for several businesses (dental clinic, barbershop, car service).

Two modes:
- "ai": an OpenAI-compatible LLM with tool calling (set LLM_API_KEY).
- "rules": a keyword parser that works offline, used when no key is set
  or the LLM call fails. The demo therefore always works.
"""
import json
import logging
import os
import re
from datetime import date, datetime, timedelta

import httpx

from . import scheduling
from .db import CATEGORIES, DOCTORS, Database

log = logging.getLogger("assistant")

# Order matters: the first specialty whose keyword is found wins.
SPECIALTY_KEYWORDS = {
    "pediatric": ["детск", "ребен", "ребён", "сын", "доч", "child", "kid"],
    "orthodontist": ["ортодонт", "брекет", "элайнер", "прикус", "orthodont", "braces"],
    "surgeon": ["хирург", "удал", "имплант", "мудр", "surgeon", "extract", "implant"],
    "hygienist": ["чистк", "гигиен", "отбел", "налет", "налёт", "whiten", "hygien"],
    "therapist": ["терапевт", "кариес", "пломб", "болит", "боль", "лечить", "лечен", "toothache", "filling", "caries"],
    "beard": ["бород", "усы", "брить", "бритьё", "бритье", "beard", "shave"],
    "coloring": ["окраш", "покрас", "тонир", "колорист", "coloring"],
    "haircut": ["стриж", "постричь", "подстричь", "укладк", "haircut"],
    "tires": ["шины", "шину", "шиномонтаж", "колес", "колёс", "резин", "переобу", "балансир", "tires", "tyre"],
    "diagnostics": ["диагност", "электрик", "ошибк", "аккумулятор", "diagnos"],
    "mechanic": ["масл", "ходов", "тормоз", "механик", "техобслуж", "oil change", "brake"],
}

CATEGORY_KEYWORDS = {
    "dental": ["зуб", "стоматолог", "дантист", "десн", "dentist", "tooth", "teeth"],
    "barber": ["барбер", "парикмахер", "волос", "причес", "причёс", "barber", "hair"],
    "auto": ["авто", "машин", "car service", "my car"],
}

CATEGORY_TITLES = {c["id"]: c["title"] for c in CATEGORIES}
SPECIALTY_CATEGORY = {d[2]: d[5] for d in DOCTORS}

WEEKDAYS = {
    0: ["понедельник", "monday"],
    1: ["вторник", "tuesday"],
    2: ["сред", "wednesday"],
    3: ["четверг", "thursday"],
    4: ["пятниц", "friday"],
    5: ["суббот", "saturday"],
    6: ["воскресен", "sunday"],
}

PARTS_OF_DAY = {
    "morning": (9, 12),
    "afternoon": (13, 18),
    "evening": (15, 18),
    "any": (9, 18),
}

MONTHS_RU = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля",
             "августа", "сентября", "октября", "ноября", "декабря"]
WEEKDAYS_RU = ["пн", "вт", "ср", "чт", "пт", "сб", "вс"]


def human_time(start: str) -> str:
    dt = datetime.strptime(start, scheduling.FMT)
    return f"{WEEKDAYS_RU[dt.weekday()]}, {dt.day} {MONTHS_RU[dt.month - 1]} в {dt:%H:%M}"


# ---------------------------------------------------------------- rules mode

def detect_specialty(text: str, category: str | None = None) -> str | None:
    for spec, words in SPECIALTY_KEYWORDS.items():
        if category and SPECIALTY_CATEGORY[spec] != category:
            continue
        if any(w in text for w in words):
            return spec
    return None


def detect_category(text: str) -> str | None:
    for cat, words in CATEGORY_KEYWORDS.items():
        if any(w in text for w in words):
            return cat
    return None


def detect_date(text: str, today: date) -> date | None:
    if "послезавтра" in text or "day after tomorrow" in text:
        return today + timedelta(days=2)
    if "завтра" in text or "tomorrow" in text:
        return today + timedelta(days=1)
    if "сегодня" in text or "today" in text:
        return today
    m = re.search(r"\b(\d{1,2})[./](\d{1,2})\b", text)
    if m:
        day, month = int(m.group(1)), int(m.group(2))
        try:
            candidate = date(today.year, month, day)
            if candidate < today:
                candidate = date(today.year + 1, month, day)
            return candidate
        except ValueError:
            pass
    for weekday, words in WEEKDAYS.items():
        if any(w in text for w in words):
            delta = (weekday - today.weekday()) % 7
            return today + timedelta(days=delta)
    return None


def detect_hours(text: str) -> tuple[int, int]:
    m = re.search(r"\b(?:в|at|на)\s*(\d{1,2})(?::00)?\b", text) or re.search(r"\b(\d{1,2}):00\b", text)
    if m:
        hour = int(m.group(1))
        if 9 <= hour < 18:
            return hour, hour + 1
    if "утр" in text or "morning" in text:
        return PARTS_OF_DAY["morning"]
    if "вечер" in text or "evening" in text:
        return PARTS_OF_DAY["evening"]
    if "после обеда" in text or "днем" in text or "днём" in text or "afternoon" in text:
        return PARTS_OF_DAY["afternoon"]
    return PARTS_OF_DAY["any"]


def _result(reply: str, slots: list | None = None, appointment: dict | None = None,
            reschedule_id: int | None = None, changed: bool = False) -> dict:
    return {
        "reply": reply,
        "slots": slots or [],
        "appointment": appointment,
        "reschedule_id": reschedule_id,
        "changed": changed,
    }


def _describe(appt: dict) -> str:
    return f"{appt['doctor_title']} {appt['doctor_name']} — {human_time(appt['start'])}"


def pick_appointment(db: Database, appts: list[dict], text: str, day: date | None = None) -> dict | None:
    """Work out which appointment the patient means; None when it is ambiguous."""
    candidates = appts
    if len(candidates) > 1:
        specialty = detect_specialty(text)
        category = detect_category(text)
        if specialty:
            ids = {d["id"] for d in scheduling.list_doctors(db, specialty)}
            candidates = [a for a in candidates if a["doctor_id"] in ids]
        elif category:
            candidates = [a for a in candidates if a["category"] == category]
    if len(candidates) > 1 and day is not None:
        candidates = [a for a in candidates if a["start"].startswith(day.isoformat())]
    return candidates[0] if len(candidates) == 1 else None


def rules_reply(db: Database, user: dict, message: str, category: str | None = None,
                doctor_id: int | None = None) -> dict:
    text = message.lower().strip()
    today = scheduling.now().date()
    day = detect_date(text, today)
    hour_from, hour_to = detect_hours(text)
    appts = scheduling.user_appointments(db, user["id"])
    listing = "\n".join(f"• {_describe(a)}" for a in appts)

    if "отмен" in text or "cancel" in text:
        if not appts:
            return _result("У вас нет активных записей.")
        target = pick_appointment(db, appts, text, day)
        if target is None:
            return _result(
                "У вас несколько записей. Уточните, какую отменить, "
                "например: «отмени запись к ортодонту».\n" + listing
            )
        scheduling.cancel(db, user["id"], target["id"])
        return _result(f"Отменил запись: {_describe(target)}.", changed=True)

    if any(w in text for w in ["перенес", "перенос", "перезапи", "reschedul"]):
        if not appts:
            return _result("У вас нет записей, которые можно перенести.")
        target = pick_appointment(db, appts, text)
        if target is None:
            return _result(
                "У вас несколько записей. Уточните, какую перенести, "
                "например: «перенеси запись к барберу на пятницу».\n" + listing
            )
        slots = scheduling.find_slots(db, [target["doctor_id"]], day, hour_from, hour_to)
        note = ""
        if not slots:
            slots = scheduling.find_slots(db, [target["doctor_id"]], None, hour_from, hour_to)
            note = "На этот день свободных окон нет. "
        if not slots:
            return _result("К сожалению, у этого специалиста нет свободных окон в ближайшие две недели.")
        return _result(
            f"{note}Сейчас вы записаны: {_describe(target)}. Выберите новое время:",
            slots=slots,
            reschedule_id=target["id"],
        )

    if "мои запис" in text or "my appointment" in text:
        if not appts:
            return _result("У вас пока нет записей. Напишите, куда и когда хотите записаться.")
        return _result("Ваши записи:\n" + listing)

    specialty = detect_specialty(text, category) or (None if category else detect_specialty(text))
    target_category = category or (SPECIALTY_CATEGORY[specialty] if specialty else detect_category(text))
    wants_booking = any(w in text for w in ["запис", "приём", "прием", "время", "слот", "book", "appointment"])

    if doctor_id is not None:
        # The client pressed "Book via AI" on a specific specialist.
        slots = scheduling.find_slots(db, [doctor_id], day, hour_from, hour_to)
        if not slots:
            slots = scheduling.find_slots(db, [doctor_id], None, hour_from, hour_to)
        if not slots:
            return _result("К сожалению, у этого специалиста нет свободных окон в ближайшие две недели.")
        return _result(
            f"Свободное время: {slots[0]['doctor_title'].lower()} {slots[0]['doctor_name']}. "
            "Нажмите на удобный слот:",
            slots=slots,
        )

    if specialty is None and target_category is None and day is None and not wants_booking:
        return _result(
            f"Здравствуйте, {user['name']}! Я ИИ-администратор Smile AI. "
            "Запишу к стоматологу, в барбершоп или автосервис. "
            "Напишите, что нужно и когда удобно, например: «болит зуб, завтра после обеда», "
            "«стрижка в субботу утром» или «замена масла в пятницу»."
        )

    doctor_ids = None
    if specialty or target_category:
        doctor_ids = [d["id"] for d in scheduling.list_doctors(db, specialty, target_category)]
    slots = scheduling.find_slots(db, doctor_ids, day, hour_from, hour_to)
    note = ""
    if not slots and day is not None:
        slots = scheduling.find_slots(db, doctor_ids, None, hour_from, hour_to)
        note = "На этот день свободных окон нет. "
    if not slots:
        return _result("К сожалению, свободных окон в ближайшие две недели нет.")
    if specialty:
        found = f"Нашёл свободное время: {slots[0]['doctor_title'].lower()}."
    elif target_category:
        found = f"Нашёл свободное время: {CATEGORY_TITLES[target_category].lower()}."
    else:
        found = "Нашёл ближайшее свободное время."
    return _result(f"{note}{found} Нажмите на удобный слот, чтобы записаться:", slots=slots)


# ------------------------------------------------------------------- AI mode

TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "find_slots",
            "description": (
                "Find free appointment slots. Call before suggesting any time. "
                "The app shows the result as tappable cards."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "category": {"type": "string", "enum": [*CATEGORY_TITLES, "any"]},
                    "specialty": {"type": "string", "enum": [*SPECIALTY_KEYWORDS, "any"]},
                    "doctor_id": {"type": "integer", "description": "Limit to one specialist (optional)"},
                    "date": {"type": "string", "description": "YYYY-MM-DD or empty for nearest days"},
                    "part_of_day": {"type": "string", "enum": ["morning", "afternoon", "evening", "any"]},
                    "reschedule_appointment_id": {
                        "type": "integer",
                        "description": "Set when the slots are offered to move this existing appointment",
                    },
                },
                "required": ["category", "specialty", "part_of_day"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "book_appointment",
            "description": "Book a slot. Only call after the client explicitly confirmed specialist and time.",
            "parameters": {
                "type": "object",
                "properties": {
                    "doctor_id": {"type": "integer"},
                    "start": {"type": "string", "description": "YYYY-MM-DDTHH:MM"},
                },
                "required": ["doctor_id", "start"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "list_my_appointments",
            "description": "List the client's upcoming appointments with their ids.",
            "parameters": {"type": "object", "properties": {}},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "cancel_appointment",
            "description": "Cancel an appointment. Only after the client clearly asked to cancel this one.",
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
            "description": "Move an appointment to a new time with the same specialist, after explicit confirmation.",
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
]


def system_prompt(db: Database, user: dict, category: str | None = None, doctor_id: int | None = None) -> str:
    today = scheduling.now()
    lines = []
    for cat in CATEGORIES:
        lines.append(f"{cat['title']} ({cat['id']}), {cat['place']}:")
        for d in scheduling.list_doctors(db, category=cat["id"]):
            lines.append(f"  - id={d['id']} {d['name']}, {d['title']} ({d['specialty']}): {d['description']}")
    selected = f"The client is browsing the '{category}' category; prefer it. " if category else ""
    if doctor_id is not None:
        selected += f"The client asked about the specialist with id={doctor_id}; search slots with this doctor_id. "
    return (
        "You are the AI administrator of Smile AI, a booking service in Bishkek. "
        f"Client name: {user['name']}. Now: {today:%Y-%m-%d %H:%M} ({today:%A}), timezone Asia/Bishkek. "
        "All places work Mon-Sat 09:00-18:00, one-hour slots.\n"
        "Businesses and specialists:\n" + "\n".join(lines) + "\n"
        f"{selected}"
        "Rules: reply in the client's language (default Russian), max 3 short sentences, friendly. "
        "Always use find_slots before offering times; never invent times. "
        "The app shows found slots as tappable cards, so do not list every slot in text. "
        "Book, cancel or reschedule only after explicit confirmation. "
        "To move an appointment, call list_my_appointments, then find_slots with doctor_id and "
        "reschedule_appointment_id. You do not give medical diagnoses."
    )


def run_tool(db: Database, user: dict, name: str, args: dict, state: dict) -> str:
    def dump(value) -> str:
        return json.dumps(value, ensure_ascii=False)

    try:
        if name == "find_slots":
            spec = args.get("specialty")
            spec = spec if spec in SPECIALTY_KEYWORDS else None
            cat = args.get("category")
            cat = cat if cat in CATEGORY_TITLES else None
            if args.get("doctor_id"):
                doctor_ids = [int(args["doctor_id"])]
            elif spec or cat:
                doctor_ids = [d["id"] for d in scheduling.list_doctors(db, spec, None if spec else cat)]
            else:
                doctor_ids = None
            day = None
            if args.get("date"):
                try:
                    day = datetime.strptime(args["date"], "%Y-%m-%d").date()
                except ValueError:
                    day = None
            hour_from, hour_to = PARTS_OF_DAY.get(args.get("part_of_day", "any"), PARTS_OF_DAY["any"])
            slots = scheduling.find_slots(db, doctor_ids, day, hour_from, hour_to)
            state["slots"] = slots
            state["reschedule_id"] = (
                int(args["reschedule_appointment_id"]) if args.get("reschedule_appointment_id") else None
            )
            return dump(slots)
        if name == "book_appointment":
            appt = scheduling.book(db, user["id"], int(args["doctor_id"]), str(args["start"]))
        elif name == "reschedule_appointment":
            appt = scheduling.reschedule(db, user["id"], int(args["appointment_id"]), str(args["start"]))
        elif name == "cancel_appointment":
            cancelled = scheduling.cancel(db, user["id"], int(args["appointment_id"]))
            state.update(slots=[], reschedule_id=None, changed=True)
            return dump({"cancelled": cancelled})
        elif name == "list_my_appointments":
            return dump(scheduling.user_appointments(db, user["id"]))
        else:
            return dump({"error": f"unknown tool {name}"})
    except (scheduling.BookingError, KeyError, ValueError, TypeError) as e:
        return dump({"error": str(e)})
    # booked or rescheduled
    state.update(appointment=appt, slots=[], reschedule_id=None, changed=True)
    return dump(appt)


def ai_reply(db: Database, user: dict, message: str, history: list[dict], category: str | None = None,
             doctor_id: int | None = None) -> dict:
    api_key = os.environ["LLM_API_KEY"]
    base_url = os.getenv("LLM_BASE_URL", "https://api.openai.com/v1").rstrip("/")
    model = os.getenv("LLM_MODEL", "gpt-4o-mini")

    messages = [{"role": "system", "content": system_prompt(db, user, category, doctor_id)}]
    for h in history[-10:]:
        role = "assistant" if h.get("role") == "assistant" else "user"
        messages.append({"role": role, "content": str(h.get("text", ""))})
    messages.append({"role": "user", "content": message})

    state: dict = {"slots": [], "appointment": None, "reschedule_id": None, "changed": False}
    with httpx.Client(timeout=40) as client:
        for _ in range(6):
            resp = client.post(
                f"{base_url}/chat/completions",
                headers={"Authorization": f"Bearer {api_key}"},
                json={"model": model, "messages": messages, "tools": TOOLS, "temperature": 0.3},
            )
            resp.raise_for_status()
            msg = resp.json()["choices"][0]["message"]
            calls = msg.get("tool_calls") or []
            if not calls:
                return _result(
                    (msg.get("content") or "").strip() or "Готово.",
                    slots=state["slots"],
                    appointment=state["appointment"],
                    reschedule_id=state["reschedule_id"] if state["slots"] else None,
                    changed=state["changed"],
                )
            messages.append({"role": "assistant", "content": msg.get("content"), "tool_calls": calls})
            for call in calls:
                try:
                    args = json.loads(call["function"].get("arguments") or "{}")
                except json.JSONDecodeError:
                    args = {}
                result = run_tool(db, user, call["function"]["name"], args, state)
                messages.append({"role": "tool", "tool_call_id": call["id"], "content": result})
    raise RuntimeError("LLM did not finish in 6 steps")


def answer(db: Database, user: dict, message: str, history: list[dict], category: str | None = None,
           doctor_id: int | None = None) -> dict:
    if category not in CATEGORY_TITLES:
        category = None
    if doctor_id is not None and db.one("SELECT id FROM doctors WHERE id = ?", (doctor_id,)) is None:
        doctor_id = None
    if os.getenv("LLM_API_KEY"):
        try:
            return {**ai_reply(db, user, message, history, category, doctor_id), "mode": "ai"}
        except Exception as e:  # network, quota, bad response -> keep the demo alive
            log.warning("LLM failed, falling back to rules: %s", e)
    return {**rules_reply(db, user, message, category, doctor_id), "mode": "rules"}
