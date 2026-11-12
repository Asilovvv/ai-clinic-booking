import json
from datetime import timedelta

import httpx

from app import assistant, clock


def names(result):
    return {s["business_name"] for s in result["slots"]}


def test_greeting_and_asking_for_a_service(api):
    h = api.register()
    hello = api.chat(h, "привет")
    assert hello["mode"] == "rules" and hello["slots"] == [] and "ИИ-администратор" in hello["reply"]
    assert "какую услугу" in api.chat(h, "запишите меня на завтра")["reply"]
    assert "нет записей" in api.chat(h, "покажи мои записи")["reply"]


def test_niche_request_offers_every_business_of_the_niche(api):
    h = api.register()
    result = api.chat(h, "Болит зуб, хочу записаться после обеда")
    assert names(result) == {"Стоматология Smile", "Dentalux"}
    assert {s["service_name"] for s in result["slots"]} == {"Консультация и осмотр"}
    assert all(int(s["start"][11:13]) >= 12 for s in result["slots"])
    assert all(s["category"] == "dental" for s in result["slots"])


def test_service_request_and_price_in_reply(api):
    h = api.register()
    result = api.chat(h, "хочу отбеливание зубов")
    assert names(result) == {"Стоматология Smile", "Dentalux"}
    one = api.chat(h, "шиномонтаж в субботу утром")
    assert names(one) == {"Автосервис Motor"}
    assert "1 200 сом" in one["reply"] and "60 мин" in one["reply"]
    assert all(s["specialist_name"] == "Эрлан Сатыбалдиев" and int(s["start"][11:13]) < 12 for s in one["slots"])
    # slots of one service are spread over the day, not packed into the first hour
    hours = [s["start"] for s in one["slots"]]
    assert len(hours) == len(set(hours)) >= 3


def test_same_word_in_different_niches(api):
    h = api.register()
    cut = api.chat(h, "стрижка завтра")
    assert names(cut) == {"Барбершоп Blade", "Barber House", "Салон красоты Aurora"}
    assert {s["service_name"] for s in cut["slots"]} == {"Мужская стрижка", "Женская стрижка"}
    assert names(api.chat(h, "стрижка", category="beauty")) == {"Салон красоты Aurora"}
    assert {s["service_name"] for s in api.chat(h, "детская стрижка")["slots"]} == {"Детская стрижка"}
    assert {s["service_name"] for s in api.chat(h, "стрижка и борода")["slots"]} == {"Стрижка и борода"}
    assert names(api.chat(h, "чистка лица")) == {"Салон красоты Aurora"}
    assert names(api.chat(h, "чистка зубов")) == {"Стоматология Smile", "Dentalux"}
    assert names(api.chat(h, "помыть машину")) == {"Автомойка Aqua"}
    assert names(api.chat(h, "Oil change on Friday")) == {"Автосервис Motor"}


def test_business_scope_specialist_and_name(api):
    h = api.register()
    blade = api.business("Барбершоп Blade")
    beard = api.chat(h, "борода", business_id=blade["id"])
    assert names(beard) == {"Барбершоп Blade"} and {s["service_name"] for s in beard["slots"]} == {"Оформление бороды"}
    menu = api.chat(h, "здравствуйте", business_id=blade["id"])
    assert menu["slots"] == [] and "Мужская стрижка — 600 сом" in menu["reply"]
    assert "Токтогула, 125" in api.chat(h, "какой у вас адрес?", business_id=blade["id"])["reply"]
    assert "ежедневно, 10:00–20:00" in api.chat(h, "где находится Blade и до скольки работает")["reply"]

    by_name = api.chat(h, "запишите к Азамату на завтра")
    assert by_name["slots"] and {s["specialist_name"] for s in by_name["slots"]} == {"Азамат Жумабеков"}
    danijar = next(sp for sp in blade["specialists"] if sp["name"] == "Данияр Исаев")
    by_id = api.chat(h, "Хочу записаться", business_id=blade["id"], specialist_id=danijar["id"])
    assert by_id["slots"] and {s["specialist_id"] for s in by_id["slots"]} == {danijar["id"]}
    assert names(api.chat(h, "стрижка в Barber House")) == {"Barber House"}
    assert names(api.chat(h, "хочу в dentalux")) == {"Dentalux"}


def test_dates_and_times(api):
    h = api.register()
    tomorrow = (clock.now().date() + timedelta(days=1)).isoformat()
    exact = api.chat(h, "маникюр завтра в 15:30")
    assert exact["slots"][0]["start"] == f"{tomorrow}T15:30"
    assert api.chat(h, "маникюр завтра в 3")["slots"][0]["start"] == f"{tomorrow}T15:00"
    day = clock.now().date() + timedelta(days=5)
    dated = api.chat(h, f"маникюр {day.day}.{day.month:02d} вечером")
    assert dated["slots"] and all(s["start"].startswith(day.isoformat()) for s in dated["slots"])
    assert all(int(s["start"][11:13]) >= 17 for s in dated["slots"])
    worded = api.chat(h, f"массаж спины {day.day} {assistant.MONTHS_RU[day.month - 1]}")
    assert worded["slots"] and all(s["start"].startswith(day.isoformat()) for s in worded["slots"])
    # a day when the place is closed falls back to the nearest free time
    sunday = clock.now().date() + timedelta(days=(6 - clock.now().weekday()) % 7 or 7)
    closed = api.chat(h, f"замена масла {sunday.day}.{sunday.month:02d}")
    assert "свободного времени нет" in closed["reply"] and closed["slots"]


def test_reschedule_and_cancel_by_chat(client, api):
    h = api.register()
    slot = api.chat(h, "стрижка в Blade")["slots"][0]
    booked = api.book(h, slot, source="chat").json()
    assert booked["source"] == "chat"
    assert "Мужская стрижка" in api.chat(h, "мои записи")["reply"]

    offer = api.chat(h, "перенеси мою запись")
    assert offer["reschedule_id"] == booked["id"]
    assert offer["slots"] and all(s["specialist_id"] == booked["specialist_id"] for s in offer["slots"])
    assert booked["start"] not in [s["start"] for s in offer["slots"]]
    moved = client.patch(f"/appointments/{booked['id']}", headers=h, json={"start": offer["slots"][0]["start"]})
    assert moved.status_code == 200

    # a second booking makes "cancel" ambiguous until the client says which one
    later = clock.now().date() + timedelta(days=6)  # far from the haircut, so the two never overlap
    wash = api.chat(h, f"помыть машину {later.day}.{later.month:02d}")["slots"][0]
    assert api.book(h, wash).status_code == 201
    unclear = api.chat(h, "отмени запись")
    assert unclear["changed"] is False and "Уточните" in unclear["reply"]
    done = api.chat(h, "отмени мойку")
    assert done["changed"] is True and "Автомойка Aqua" in done["reply"]
    left = [a for a in client.get("/appointments", headers=h).json() if a["upcoming"]]
    assert [a["business_name"] for a in left] == ["Барбершоп Blade"]
    assert api.chat(h, "отмени запись")["changed"] is True
    assert "нет активных" in api.chat(h, "отмени запись")["reply"]


def _fake_llm(monkeypatch, steps):
    """Replace the LLM with a script: each step is a list of tool calls or a final text."""
    calls = {"n": 0, "seen": []}

    def handler(request: httpx.Request) -> httpx.Response:
        payload = json.loads(request.content)
        calls["seen"].append(payload["messages"])
        step = steps[calls["n"]]
        calls["n"] += 1
        if callable(step):
            step = step(payload["messages"])
        if isinstance(step, str):
            return httpx.Response(200, json={"choices": [{"message": {"content": step}}]})
        tool_calls = [{"id": f"c{i}", "type": "function", "function": {"name": name, "arguments": json.dumps(args)}}
                      for i, (name, args) in enumerate(step)]
        return httpx.Response(200, json={"choices": [{"message": {"content": None, "tool_calls": tool_calls}}]})

    real = httpx.Client
    monkeypatch.setattr(assistant.httpx, "Client", lambda **kw: real(transport=httpx.MockTransport(handler)))
    monkeypatch.setenv("LLM_API_KEY", "test")
    return calls


def test_ai_mode_searches_finds_and_books(client, api, monkeypatch):
    def find(messages):
        services = json.loads(messages[-1]["content"])
        assert {s["service"] for s in services} == {"Удаление зуба"}
        return [("find_slots", {"service_id": services[0]["service_id"], "part_of_day": "any"})]

    def book(messages):
        slot = json.loads(messages[-1]["content"])[0]
        return [("book_appointment", {"service_id": slot["service_id"], "specialist_id": slot["specialist_id"],
                                      "start": slot["start"]})]

    calls = _fake_llm(monkeypatch, [[("search_services", {"query": "удалить зуб"})], find, book, "Записал вас."])
    h = api.register()
    result = api.chat(h, "удалить зуб, запиши на ближайшее")
    assert result["mode"] == "ai" and result["reply"] == "Записал вас." and result["changed"] is True
    assert result["appointment"]["service_name"] == "Удаление зуба" and result["appointment"]["source"] == "chat"
    assert "Niches:" in calls["seen"][0][0]["content"]
    assert len(client.get("/appointments", headers=h).json()) == 1


def test_ai_mode_knows_the_business_it_serves(api, monkeypatch):
    calls = _fake_llm(monkeypatch, ["Здравствуйте!"])
    blade = api.business("Барбершоп Blade")
    api.chat(api.register(), "привет", business_id=blade["id"])
    prompt = calls["seen"][0][0]["content"]
    assert "«Барбершоп Blade»" in prompt and "Мужская стрижка: 600 som" in prompt


def test_falls_back_to_rules_when_the_llm_is_down(api, monkeypatch):
    monkeypatch.setenv("LLM_API_KEY", "bad")
    monkeypatch.setenv("LLM_BASE_URL", "http://127.0.0.1:9")  # nothing listens here
    result = api.chat(api.register(), "йога завтра утром")
    assert result["mode"] == "rules" and names(result) == {"FitZone"}
