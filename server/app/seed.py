"""Demo data: businesses in every niche, a demo client, a demo owner and some history.

Runs once on an empty database. Turn it off in production with SEED_DEMO=0;
SEED_HISTORY=0 keeps the businesses but skips generated bookings and reviews.
"""
import os
import random
from datetime import datetime, timedelta

from . import auth, clock, scheduling
from .catalog import CATEGORY_BY_ID, service_keywords
from .db import appointments, businesses, reviews, services, specialist_services, specialists

DEMO_CUSTOMER_EMAIL = "demo@smile.kg"
DEMO_OWNER_EMAIL = "owner@smile.kg"

# staff: (name, title, indexes of the niche template services they perform)
DEMO_BUSINESSES = [
    {
        "category": "dental", "name": "Стоматология Smile", "address": "ул. Киевская, 95",
        "phone": "+996 555 100 200", "hours": (9, 18), "days": "0,1,2,3,4,5", "demo_owner": True,
        "description": "Современная клиника в центре Бишкека. Лечение без боли, детский приём.",
        "staff": [
            ("Айгуль Садыкова", "Терапевт-стоматолог", [0, 1]),
            ("Нурлан Абдыкадыров", "Хирург-имплантолог", [0, 4]),
            ("Элина Ким", "Ортодонт", [5]),
            ("Бакыт Осмонов", "Гигиенист", [2, 3]),
            ("Мира Токтогулова", "Детский стоматолог", [6]),
        ],
    },
    {
        "category": "dental", "name": "Dentalux", "address": "пр. Чуй, 150", "phone": "+996 700 210 310",
        "hours": (10, 20), "days": "0,1,2,3,4,5,6", "price_factor": 1.3, "services": [0, 1, 2, 3, 4],
        "description": "Семейная стоматология. Работаем без выходных.",
        "staff": [("Асел Турдубаева", "Стоматолог", [0, 1, 2, 3]), ("Тимур Алиев", "Хирург", [0, 4])],
    },
    {
        "category": "clinic", "name": "Медцентр Vita", "address": "ул. Московская, 189", "phone": "+996 312 900 100",
        "hours": (8, 18), "days": "0,1,2,3,4,5",
        "description": "Приём врачей, УЗИ и анализы в одном месте.",
        "staff": [
            ("Гульмира Асанбекова", "Терапевт", [0]),
            ("Канат Орозбеков", "Врач УЗИ", [1]),
            ("Назира Кадырова", "Медсестра", [2]),
            ("Улан Бейшеналиев", "Кардиолог", [3]),
        ],
    },
    {
        "category": "barber", "name": "Барбершоп Blade", "address": "ул. Токтогула, 125", "phone": "+996 555 320 420",
        "hours": (10, 20), "days": "0,1,2,3,4,5,6",
        "description": "Мужские стрижки и уход за бородой. Кофе за наш счёт.",
        "staff": [("Азамат Жумабеков", "Барбер", [0, 2, 3]), ("Данияр Исаев", "Барбер-бородист", [0, 1, 2, 4])],
    },
    {
        "category": "barber", "name": "Barber House", "address": "ул. Ахунбаева, 98", "phone": "+996 770 430 530",
        "hours": (9, 21), "days": "0,1,2,3,4,5,6", "price_factor": 0.8, "services": [0, 1, 2, 3],
        "description": "Быстро, аккуратно и недорого.",
        "staff": [("Адилет Маматов", "Барбер", [0, 1, 2, 3])],
    },
    {
        "category": "beauty", "name": "Салон красоты Aurora", "address": "ул. Исанова, 42", "phone": "+996 555 540 640",
        "hours": (9, 20), "days": "0,1,2,3,4,5,6",
        "description": "Маникюр, брови, ресницы, волосы и уход за лицом.",
        "staff": [
            ("Жанара Бекова", "Мастер маникюра", [0, 1]),
            ("Сезим Асанова", "Бровист-лешмейкер", [2, 3]),
            ("Алина Ниязова", "Стилист-колорист", [4, 5]),
            ("Асель Мамытова", "Косметолог", [6]),
        ],
    },
    {
        "category": "massage", "name": "Relax SPA", "address": "ул. Горького, 27", "phone": "+996 700 650 750",
        "hours": (10, 21), "days": "0,1,2,3,4,5,6",
        "description": "Массаж и СПА-программы для отдыха после работы.",
        "staff": [("Гульнара Исакова", "Массажист", [0, 1, 2]), ("Эрик Байтиков", "Массажист", [0, 1])],
    },
    {
        "category": "fitness", "name": "FitZone", "address": "ул. Байтик Баатыра, 61", "phone": "+996 555 760 860",
        "hours": (7, 22), "days": "0,1,2,3,4,5,6",
        "description": "Персональные тренировки, йога и стретчинг.",
        "staff": [("Эмиль Чотбаев", "Персональный тренер", [0, 2]), ("Айпери Нурланова", "Инструктор йоги", [1, 2])],
    },
    {
        "category": "auto", "name": "Автосервис Motor", "address": "ул. Льва Толстого, 36", "phone": "+996 312 870 970",
        "hours": (9, 18), "days": "0,1,2,3,4,5",
        "description": "Диагностика, масло, шины и ходовая. Честные сроки.",
        "staff": [
            ("Тимур Касымов", "Диагност-электрик", [0]),
            ("Руслан Ибраимов", "Автомеханик", [1, 3, 4]),
            ("Эрлан Сатыбалдиев", "Шиномонтажник", [2]),
        ],
    },
    {
        "category": "carwash", "name": "Автомойка Aqua", "address": "ул. Жибек Жолу, 310", "phone": "+996 770 980 180",
        "hours": (8, 22), "days": "0,1,2,3,4,5,6",
        "description": "Два бокса, запись ко времени без очереди.",
        "staff": [("Бокс 1", "Мойка", [0, 1, 2, 3]), ("Бокс 2", "Мойка", [0, 1])],
    },
    {
        "category": "tutor", "name": "Учебный центр Bilim", "address": "ул. Абдрахманова, 170", "phone": "+996 555 190 290",
        "hours": (9, 20), "days": "0,1,2,3,4,5",
        "description": "Английский, математика, подготовка к ОРТ и программирование.",
        "staff": [
            ("Айдана Осмонова", "Преподаватель английского", [0]),
            ("Марат Жээнбеков", "Преподаватель математики", [1, 2]),
            ("Бекжан Усенов", "Преподаватель программирования", [3]),
        ],
    },
    {
        "category": "vet", "name": "Ветклиника ZooDoc", "address": "ул. Суюмбаева, 14", "phone": "+996 700 300 400",
        "hours": (9, 19), "days": "0,1,2,3,4,5,6",
        "description": "Приём, вакцинация и груминг для кошек и собак.",
        "staff": [("Нурбек Сыдыков", "Ветеринар", [0, 1, 3]), ("Алтынай Токтосунова", "Грумер", [2])],
    },
]

FAKE_CLIENTS = [
    "Айбек Маматов", "Алина Сыдыкова", "Нурлан Жолдошев", "Чолпон Абдраева",
    "Эрмек Турсунов", "Айжан Кубатова", "Бермет Исакова", "Тилек Орозов",
]

COMMENTS = {
    5: ["Всё отлично, рекомендую!", "Быстро и качественно.", "Очень внимательный мастер.",
        "Записалась за минуту, приняли вовремя.", "Лучший сервис в городе."],
    4: ["Хорошо, но пришлось немного подождать.", "В целом доволен.", "Качественно, цены средние."],
    3: ["Нормально, без восторга."],
}


def demo_enabled() -> bool:
    return os.getenv("SEED_DEMO", "1") != "0"


def ensure_seed(db) -> None:
    """Fill an empty database with demo data."""
    if not demo_enabled() or db.one("SELECT id FROM businesses LIMIT 1"):
        return
    with db.begin() as tx:
        _seed(tx, with_history=os.getenv("SEED_HISTORY", "1") != "0")


def _seed(tx, with_history: bool) -> None:
    password = os.getenv("DEMO_PASSWORD", "demo1234")
    demo_owner = auth.create_user(tx, "Бектур", DEMO_OWNER_EMAIL, password, role="owner")
    demo_customer = auth.create_user(tx, "Айдай", DEMO_CUSTOMER_EMAIL, password)
    other_owner = auth.create_user(tx, "Smile AI", "partners@smile.local", None, role="owner")
    clients = [
        auth.create_user(tx, name, f"client{i}@smile.local", None)["id"] for i, name in enumerate(FAKE_CLIENTS, 1)
    ]

    rng = random.Random(20261112)
    for spec in DEMO_BUSINESSES:
        category = CATEGORY_BY_ID[spec["category"]]
        is_demo = spec.get("demo_owner", False)
        business_id = tx.insert(
            businesses,
            owner_id=(demo_owner if is_demo else other_owner)["id"],
            category=category["id"],
            name=spec["name"],
            description=spec["description"],
            address=spec["address"],
            phone=spec["phone"],
            open_hour=spec["hours"][0],
            close_hour=spec["hours"][1],
            working_days=spec["days"],
            is_active=1,
            created_at=clock.stamp(),
        )
        factor = spec.get("price_factor", 1.0)
        service_ids: dict = {}
        for order, index in enumerate(spec.get("services") or range(len(category["services"]))):
            name, duration, price, keywords = category["services"][index]
            service_ids[index] = tx.insert(
                services, business_id=business_id, name=name, description="", duration_min=duration,
                price=int(round(price * factor / 50.0)) * 50, keywords=service_keywords(name, keywords),
                is_active=1, sort_order=order,
            )
        for order, (name, title, performs) in enumerate(spec["staff"]):
            specialist_id = tx.insert(
                specialists, business_id=business_id, name=name, title=title, is_active=1, sort_order=order
            )
            for index in performs:
                if index in service_ids:
                    tx.insert(specialist_services, specialist_id=specialist_id, service_id=service_ids[index])
        if with_history:
            if is_demo:
                _history(tx, rng, business_id, clients, days_back=14, per_day=(1, 4), days_ahead=3)
            else:
                _history(tx, rng, business_id, clients, days_back=12, per_day=(0, 2), days_ahead=0)

    if with_history:
        _past_visit(tx, demo_customer["id"])


def _history(tx, rng, business_id: int, clients: list[int], days_back: int, per_day: tuple, days_ahead: int) -> None:
    """Generate believable past visits with reviews and, with `days_ahead`, bookings from today on."""
    offers = scheduling.load_offers(tx, business_id=business_id)
    at = clock.now()
    used: dict = {}
    visitors: dict = {}  # day -> people already booked: nobody comes twice a day
    for offset in range(-days_back, days_ahead):
        day = at.date() + timedelta(days=offset)
        count = rng.randint(*per_day) if offset < 0 else rng.randint(3, 5)
        for _ in range(count):
            offer = rng.choice(offers)
            if day.weekday() not in offer["days"]:
                continue
            last = offer["close_hour"] * 60 - offer["duration_min"]
            minute = rng.randrange(offer["open_hour"] * 60, last + 1, scheduling.GRID)
            start = datetime(day.year, day.month, day.day) + timedelta(minutes=minute)
            past = start <= at  # earlier today counts as a finished visit
            taken = used.setdefault((offer["specialist_id"], day), [])
            if any(minute < e and s < minute + offer["duration_min"] for s, e in taken):
                continue
            taken.append((minute, minute + offer["duration_min"]))

            status = rng.choices(["completed", "no_show", "cancelled"], [80, 8, 12])[0] if past else "booked"
            source = rng.choices(["chat", "app", "owner"], [55, 33, 12])[0]
            # clients[i] is the account of FAKE_CLIENTS[i]; a walk-in is the same person without an account
            free = [i for i in range(len(clients)) if i not in visitors.setdefault(day, set())]
            if not free:
                continue
            person = rng.choice(free)
            visitors[day].add(person)
            customer_id = None if source == "owner" else clients[person]
            appointment_id = tx.insert(
                appointments,
                business_id=business_id,
                service_id=offer["service_id"],
                specialist_id=offer["specialist_id"],
                customer_id=customer_id,
                client_name=FAKE_CLIENTS[person] if customer_id is None else None,
                client_phone="+996 555 000 111" if customer_id is None else None,
                starts_at=start.strftime(scheduling.FMT),
                ends_at=(start + timedelta(minutes=offer["duration_min"])).strftime(scheduling.FMT),
                duration_min=offer["duration_min"],
                price=offer["price"],
                status=status,
                source=source,
                note="",
                created_at=(start - timedelta(days=rng.randint(1, 3))).strftime(scheduling.FMT),
            )
            if status == "completed" and customer_id is not None and rng.random() < 0.65:
                rating = rng.choices([5, 4, 3], [62, 30, 8])[0]
                tx.insert(
                    reviews, appointment_id=appointment_id, business_id=business_id, customer_id=customer_id,
                    rating=rating, comment=rng.choice(COMMENTS[rating]),
                    created_at=(start + timedelta(hours=3)).strftime(scheduling.FMT),
                )


def _past_visit(tx, customer_id: int) -> None:
    """Give the demo client one finished visit, so the history and "rate" can be shown."""
    offer = next((o for o in scheduling.load_offers(tx) if o["category"] == "barber"), None)
    if offer is None:
        return
    day = clock.now().date() - timedelta(days=3)
    start = datetime(day.year, day.month, day.day, 12, 0)
    tx.insert(
        appointments,
        business_id=offer["business_id"], service_id=offer["service_id"], specialist_id=offer["specialist_id"],
        customer_id=customer_id, client_name=None, client_phone=None,
        starts_at=start.strftime(scheduling.FMT),
        ends_at=(start + timedelta(minutes=offer["duration_min"])).strftime(scheduling.FMT),
        duration_min=offer["duration_min"], price=offer["price"], status="completed", source="chat", note="",
        created_at=(start - timedelta(days=1)).strftime(scheduling.FMT),
    )
