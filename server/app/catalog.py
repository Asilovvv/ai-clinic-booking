"""Niches (business categories) with templates of typical services.

A template service is (name, duration in minutes, price in som, keyword stems).
Keyword stems are what the offline assistant looks for in a client's message:
a stem of four or more letters matches the beginning of a word ("стриж" matches
"стрижка", "стрижку"); a shorter one must equal the whole word ("узи").

Keep service keywords specific. A word that names the whole niche ("зуб",
"массаж") belongs to the category keywords: when only the niche is recognised,
the first service of the template is offered, so put the entry-level service first.
"""
import re

CATEGORIES = [
    {
        "id": "dental",
        "title": "Стоматология",
        "specialist_title": "Стоматолог",
        "keywords": ["зуб", "зуба", "зубу", "зубы", "зубо", "зубн", "зубе", "стоматолог", "дантист", "десн",
                     "tooth", "teeth", "dent"],
        "services": [
            ("Консультация и осмотр", 30, 500, ["консультац", "осмотр", "проверить", "checkup"]),
            ("Лечение кариеса", 60, 2500, ["кариес", "пломб", "лечен", "лечить", "filling", "caries"]),
            ("Профессиональная чистка зубов", 60, 2000, ["чистк", "гигиен", "налет", "cleaning"]),
            ("Отбеливание зубов", 90, 6000, ["отбел", "whiten"]),
            ("Удаление зуба", 60, 1500, ["удал", "вырвать", "мудрост", "extract"]),
            ("Консультация ортодонта (брекеты)", 30, 700, ["брекет", "ортодонт", "прикус", "элайнер", "braces"]),
            ("Детский приём", 30, 600, ["детск", "ребен", "сын", "сына", "сыну", "дочк", "дочер", "дочь", "child", "kid"]),
        ],
    },
    {
        "id": "clinic",
        "title": "Медицинский центр",
        "specialist_title": "Врач",
        "keywords": ["врач", "доктор", "медцентр", "клиник", "поликлиник", "больниц", "doctor", "clinic"],
        "services": [
            ("Приём терапевта", 30, 800, ["терапевт", "простуд", "температур", "кашел", "therapist"]),
            ("УЗИ", 30, 1200, ["узи", "ultrasound"]),
            ("Анализ крови", 30, 600, ["анализ", "кров", "blood"]),
            ("Приём кардиолога", 30, 1000, ["кардиолог", "сердц", "давлен", "cardio"]),
        ],
    },
    {
        "id": "barber",
        "title": "Барбершоп",
        "specialist_title": "Барбер",
        "keywords": ["барбер", "парикмахер", "barber"],
        "services": [
            ("Мужская стрижка", 60, 600, ["стриж", "постричь", "подстричь", "haircut"]),
            ("Оформление бороды", 30, 400, ["бород", "усы", "брить", "бритье", "beard", "shave"]),
            ("Стрижка и борода", 90, 900, ["стриж", "бород"]),
            ("Детская стрижка", 30, 400, ["детск", "стриж"]),
            ("Камуфляж седины", 60, 1000, ["седин", "камуфляж"]),
        ],
    },
    {
        "id": "beauty",
        "title": "Салон красоты",
        "specialist_title": "Мастер",
        "keywords": ["красот", "бьюти", "beauty"],
        "services": [
            ("Маникюр с покрытием", 90, 1200, ["маникюр", "ногт", "гель", "manicur", "nail"]),
            ("Педикюр", 90, 1500, ["педикюр", "pedicur"]),
            ("Оформление бровей", 30, 500, ["бров", "brow"]),
            ("Наращивание ресниц", 120, 2000, ["ресниц", "lash"]),
            ("Женская стрижка", 60, 1000, ["женск", "стриж"]),
            ("Окрашивание волос", 120, 3000, ["окраш", "покрас", "волос", "coloring"]),
            ("Чистка лица", 60, 1800, ["чистк", "лица", "лицо", "косметолог", "facial"]),
        ],
    },
    {
        "id": "massage",
        "title": "Массаж и СПА",
        "specialist_title": "Массажист",
        "keywords": ["массаж", "спа", "massag", "spa"],
        "services": [
            ("Классический массаж", 60, 1500, ["классич", "расслаб", "общий"]),
            ("Массаж спины", 30, 800, ["спин", "шея", "шеи", "поясниц", "back"]),
            ("СПА-программа", 120, 4000, ["программ", "обертыв"]),
        ],
    },
    {
        "id": "fitness",
        "title": "Фитнес и спорт",
        "specialist_title": "Тренер",
        "keywords": ["фитнес", "спортзал", "тренаж", "fitness", "gym"],
        "services": [
            ("Персональная тренировка", 60, 1000, ["тренир", "тренер", "персональн", "training", "workout"]),
            ("Йога", 60, 600, ["йога", "йогу", "йоги", "йоге", "yoga"]),
            ("Стретчинг", 60, 600, ["стретч", "растяж", "stretch"]),
        ],
    },
    {
        "id": "auto",
        "title": "Автосервис",
        "specialist_title": "Мастер",
        "keywords": ["автосервис", "машин", "автомобил", "тачк", "car"],
        "services": [
            ("Компьютерная диагностика", 30, 800, ["диагност", "ошибк", "чек", "diagnos"]),
            ("Замена масла", 30, 1000, ["масл", "oil"]),
            ("Шиномонтаж", 60, 1200, ["шиномонтаж", "шины", "шину", "колес", "резин", "переобу", "tires", "tyre"]),
            ("Замена тормозных колодок", 60, 1500, ["тормоз", "колодк", "brake"]),
            ("Ремонт ходовой", 120, 3000, ["ходов", "подвеск", "стук", "suspens"]),
        ],
    },
    {
        "id": "carwash",
        "title": "Автомойка",
        "specialist_title": "Мойка",
        "keywords": ["автомойк", "мойк", "помыть", "вымыть", "мыть", "wash"],
        "services": [
            # "помыть машину" must beat the car service, which also knows the word "машина"
            ("Комплексная мойка", 60, 700, ["комплексн", "мойк", "помыть", "вымыть", "мыть", "wash"]),
            ("Экспресс-мойка", 30, 400, ["экспресс", "быстр", "express", "мойк"]),
            ("Химчистка салона", 120, 5000, ["химчист", "сидень"]),
            ("Полировка кузова", 120, 6000, ["полиров", "polish"]),
        ],
    },
    {
        "id": "tutor",
        "title": "Репетиторы и курсы",
        "specialist_title": "Преподаватель",
        "keywords": ["репетитор", "урок", "курс", "учител", "преподавател", "tutor", "lesson"],
        "services": [
            ("Английский язык", 60, 700, ["английск", "english", "ielts"]),
            ("Математика", 60, 600, ["математ", "алгебр", "геометр", "math"]),
            ("Подготовка к ОРТ", 90, 900, ["орт", "ort"]),
            ("Программирование на Python", 60, 1000, ["программир", "python", "код"]),
        ],
    },
    {
        "id": "vet",
        "title": "Ветклиника",
        "specialist_title": "Ветеринар",
        "keywords": [
            "ветеринар", "ветклиник", "ветврач", "питом", "кошк", "котен", "котик",
            "собак", "щенк", "животн", "vet", "pet",
        ],
        "services": [
            ("Приём ветеринара", 30, 700, []),
            ("Вакцинация", 30, 900, ["вакцин", "привив", "vaccin"]),
            ("Груминг", 60, 1500, ["груминг", "groom"]),
            ("Стерилизация", 120, 4500, ["стерилиз", "кастрац"]),
        ],
    },
]

CATEGORY_BY_ID = {c["id"]: c for c in CATEGORIES}

DURATIONS = (30, 60, 90, 120, 150, 180)

# Words too general to tell one service from another.
_STOP_WORDS = {
    "для", "или", "при", "под", "над", "без", "the", "and", "for", "with",
    "прием", "услуга", "услуги", "сеанс", "запись", "процедура", "первичный", "повторный",
}


def normalize(text: str) -> str:
    return text.lower().replace("ё", "е").strip()


def _generic_stems() -> list[str]:
    stems = []
    for category in CATEGORIES:
        stems += category["keywords"]
    return stems


def name_stems(name: str, drop_generic: bool = True) -> list[str]:
    """Derive keyword stems from a free-form name ("Маникюр с покрытием" -> маник, покрыт).

    Long words lose their ending so that other grammatical forms still match.
    Words that only name a niche ("стоматолог") are skipped: they would make
    one service win every general request.
    """
    generic = _generic_stems() if drop_generic else []
    stems: list[str] = []
    for word in re.findall(r"[a-zа-я0-9]+", normalize(name)):
        if word in _STOP_WORDS or word.isdigit():
            continue
        if len(word) < 3:
            continue
        stem = word if len(word) <= 4 else word[: max(4, len(word) - 2)]
        if any(stem.startswith(g) or g.startswith(stem) for g in generic if len(g) > 3):
            continue
        if stem not in stems:
            stems.append(stem)
    return stems


def service_keywords(name: str, explicit=None) -> str:
    """Keywords stored with a service.

    Template services come with a hand-picked list (possibly empty); a service
    typed in by an owner gets stems derived from its name.
    """
    stems = name_stems(name) if explicit is None else [normalize(k) for k in explicit]
    return ",".join(dict.fromkeys(stems))


def public_categories() -> list[dict]:
    return [{"id": c["id"], "title": c["title"], "specialist_title": c["specialist_title"]} for c in CATEGORIES]
