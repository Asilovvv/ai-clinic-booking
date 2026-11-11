"""AI booking assistant.

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
from .db import Database

log = logging.getLogger("assistant")

SPECIALTY_KEYWORDS = {
    "pediatric": ["дет", "ребен", "ребён", "сын", "доч", "child", "kid"],
    "orthodontist": ["ортодонт", "брекет", "элайнер", "прикус", "orthodont", "braces"],
    "surgeon": ["хирург", "удал", "имплант", "мудр", "surgeon", "extract", "implant"],
    "hygienist": ["чистк", "гигиен", "отбел", "налет", "налёт", "clean", "whiten", "hygien"],
    "therapist": ["терапевт", "кариес", "пломб", "болит", "боль", "лечить", "лечен", "pain", "filling", "caries"],
}

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

def detect_specialty(text: str) -> str | None:
    for spec, words in SPECIALTY_KEYWORDS.items():
        if any(w in text for w in words):
            return spec
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


def rules_reply(db: Database, user: dict, message: str) -> dict:
    text = message.lower().strip()

    if "мои запис" in text or "my appointment" in text:
        appts = scheduling.user_appointments(db, user["id"])
        if not appts:
            reply = "У вас пока нет записей. Напишите, к какому врачу и когда хотите прийти."
        else:
            lines = [f"• {a['doctor_title']} {a['doctor_name']} — {human_time(a['start'])}" for a in appts]
            reply = "Ваши записи:\n" + "\n".join(lines)
        return {"reply": reply, "slots": [], "appointment": None}

    if "отмен" in text or "cancel" in text:
        return {
            "reply": "Отменить запись можно во вкладке «Записи» — нажмите на крестик у нужной записи.",
            "slots": [],
            "appointment": None,
        }

    specialty = detect_specialty(text)
    day = detect_date(text, scheduling.now().date())
    hour_from, hour_to = detect_hours(text)
    wants_booking = any(w in text for w in ["запис", "приём", "прием", "время", "слот", "book", "appointment"])

    if specialty is None and day is None and not wants_booking:
        return {
            "reply": (
                f"Здравствуйте, {user['name']}! Я ИИ-администратор клиники «Smile». "
                "Опишите проблему и удобное время, например: «болит зуб, завтра после обеда» "
                "или «чистка в субботу утром» — и я подберу свободные окна."
            ),
            "slots": [],
            "appointment": None,
        }

    doctor_ids = [d["id"] for d in scheduling.list_doctors(db, specialty)] if specialty else None
    slots = scheduling.find_slots(db, doctor_ids, day, hour_from, hour_to)
    if not slots and day is not None:
        slots = scheduling.find_slots(db, doctor_ids, None, hour_from, hour_to)
        prefix = "На этот день свободных окон нет. Ближайшие варианты:"
    elif slots:
        who = slots[0]["doctor_title"].lower() if specialty else "врачам"
        prefix = f"Нашёл свободное время ({who}). Нажмите на удобный слот, чтобы записаться:"
    else:
        prefix = ""
    reply = prefix if slots else "К сожалению, свободных окон в ближайшие две недели нет."
    return {"reply": reply, "slots": slots, "appointment": None}


# ------------------------------------------------------------------- AI mode

TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "find_slots",
            "description": "Find free appointment slots. Call before suggesting any time.",
            "parameters": {
                "type": "object",
                "properties": {
                    "specialty": {
                        "type": "string",
                        "enum": ["therapist", "surgeon", "orthodontist", "hygienist", "pediatric", "any"],
                    },
                    "date": {"type": "string", "description": "YYYY-MM-DD or empty for nearest days"},
                    "part_of_day": {"type": "string", "enum": ["morning", "afternoon", "evening", "any"]},
                },
                "required": ["specialty", "part_of_day"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "book_appointment",
            "description": "Book a slot. Only call after the patient explicitly confirmed doctor and time.",
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
            "description": "List the patient's upcoming appointments.",
            "parameters": {"type": "object", "properties": {}},
        },
    },
]


def system_prompt(db: Database, user: dict) -> str:
    today = scheduling.now()
    doctors = "\n".join(
        f"- id={d['id']} {d['name']}, {d['title']} ({d['specialty']}): {d['description']}"
        for d in scheduling.list_doctors(db)
    )
    return (
        "You are the AI administrator of the dental clinic 'Smile' in Bishkek. "
        f"Patient name: {user['name']}. Now: {today:%Y-%m-%d %H:%M} ({today:%A}), timezone Asia/Bishkek. "
        "Clinic works Mon-Sat 09:00-18:00, one-hour slots.\n"
        f"Doctors:\n{doctors}\n"
        "Rules: reply in the patient's language (default Russian), max 3 short sentences, friendly. "
        "Always use find_slots before offering times; never invent times. "
        "The app shows found slots as tappable cards, so do not list every slot in text. "
        "Book only after explicit confirmation. You do not give medical diagnoses."
    )


def run_tool(db: Database, user: dict, name: str, args: dict, state: dict) -> str:
    if name == "find_slots":
        spec = args.get("specialty")
        doctor_ids = [d["id"] for d in scheduling.list_doctors(db, spec)] if spec and spec != "any" else None
        day = None
        if args.get("date"):
            try:
                day = datetime.strptime(args["date"], "%Y-%m-%d").date()
            except ValueError:
                day = None
        hour_from, hour_to = PARTS_OF_DAY.get(args.get("part_of_day", "any"), PARTS_OF_DAY["any"])
        slots = scheduling.find_slots(db, doctor_ids, day, hour_from, hour_to)
        state["slots"] = slots
        return json.dumps(slots, ensure_ascii=False)
    if name == "book_appointment":
        try:
            appt = scheduling.book(db, user["id"], int(args["doctor_id"]), str(args["start"]))
        except (scheduling.BookingError, KeyError, ValueError) as e:
            return json.dumps({"error": str(e)}, ensure_ascii=False)
        state["appointment"] = appt
        state["slots"] = []
        return json.dumps(appt, ensure_ascii=False)
    if name == "list_my_appointments":
        return json.dumps(scheduling.user_appointments(db, user["id"]), ensure_ascii=False)
    return json.dumps({"error": f"unknown tool {name}"})


def ai_reply(db: Database, user: dict, message: str, history: list[dict]) -> dict:
    api_key = os.environ["LLM_API_KEY"]
    base_url = os.getenv("LLM_BASE_URL", "https://api.openai.com/v1").rstrip("/")
    model = os.getenv("LLM_MODEL", "gpt-4o-mini")

    messages = [{"role": "system", "content": system_prompt(db, user)}]
    for h in history[-10:]:
        role = "assistant" if h.get("role") == "assistant" else "user"
        messages.append({"role": role, "content": str(h.get("text", ""))})
    messages.append({"role": "user", "content": message})

    state: dict = {"slots": [], "appointment": None}
    with httpx.Client(timeout=40) as client:
        for _ in range(5):
            resp = client.post(
                f"{base_url}/chat/completions",
                headers={"Authorization": f"Bearer {api_key}"},
                json={"model": model, "messages": messages, "tools": TOOLS, "temperature": 0.3},
            )
            resp.raise_for_status()
            msg = resp.json()["choices"][0]["message"]
            calls = msg.get("tool_calls") or []
            if not calls:
                return {
                    "reply": (msg.get("content") or "").strip() or "Готово.",
                    "slots": state["slots"],
                    "appointment": state["appointment"],
                }
            messages.append({"role": "assistant", "content": msg.get("content"), "tool_calls": calls})
            for call in calls:
                try:
                    args = json.loads(call["function"].get("arguments") or "{}")
                except json.JSONDecodeError:
                    args = {}
                result = run_tool(db, user, call["function"]["name"], args, state)
                messages.append({"role": "tool", "tool_call_id": call["id"], "content": result})
    raise RuntimeError("LLM did not finish in 5 steps")


def answer(db: Database, user: dict, message: str, history: list[dict]) -> dict:
    if os.getenv("LLM_API_KEY"):
        try:
            return {**ai_reply(db, user, message, history), "mode": "ai"}
        except Exception as e:  # network, quota, bad response -> keep the demo alive
            log.warning("LLM failed, falling back to rules: %s", e)
    return {**rules_reply(db, user, message), "mode": "rules"}
