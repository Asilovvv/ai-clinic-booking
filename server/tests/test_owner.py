from datetime import timedelta

from app import clock, seed
from app import db as dbmod

NEW_BUSINESS = {
    "category": "beauty", "name": "Тату-студия Ink", "address": "ул. Фрунзе, 300", "phone": "+996 500 000 001",
    "open_hour": 11, "close_hour": 21, "working_days": [1, 2, 3, 4, 5, 6],
}


def test_owner_creates_business_from_template(client, api):
    owner = api.register(role="owner", name="Айгерим")
    assert client.get("/owner/business", headers=owner).json() is None
    assert client.get("/owner/appointments", headers=owner).status_code == 404

    r = client.post("/owner/business", headers=owner, json=NEW_BUSINESS)
    assert r.status_code == 201, r.text
    business = r.json()
    assert business["name"] == "Тату-студия Ink" and business["working_days"] == [1, 2, 3, 4, 5, 6]
    assert [s["name"] for s in business["services"]][:2] == ["Маникюр с покрытием", "Педикюр"]
    assert [sp["name"] for sp in business["specialists"]] == ["Айгерим"]
    assert all(s["specialist_ids"] == [business["specialists"][0]["id"]] for s in business["services"])
    assert client.get("/owner/business", headers=owner).json()["id"] == business["id"]
    assert client.post("/owner/business", headers=owner, json=NEW_BUSINESS).status_code == 400
    assert business["id"] in [b["id"] for b in client.get("/businesses").json()]

    # wrong input
    other = api.register(role="owner")
    assert client.post("/owner/business", headers=other, json={**NEW_BUSINESS, "category": "nope"}).status_code == 400
    assert client.post("/owner/business", headers=other, json={**NEW_BUSINESS, "open_hour": 20, "close_hour": 9}).status_code == 400
    assert client.post("/owner/business", headers=other, json={**NEW_BUSINESS, "working_days": []}).status_code == 400
    empty = client.post("/owner/business", headers=other, json={**NEW_BUSINESS, "use_template": False}).json()
    assert empty["services"] == [] and len(empty["specialists"]) == 1


def test_only_owners_reach_the_cabinet(client, api):
    customer = api.register()
    assert client.get("/owner/business", headers=customer).status_code == 403
    assert client.post("/owner/business", headers=customer, json=NEW_BUSINESS).status_code == 403
    assert client.get("/owner/stats", headers=customer).status_code == 403
    assert client.get("/owner/business").status_code == 401


def test_services_and_staff(client, api):
    owner = api.register(role="owner", name="Айгерим")
    business = client.post("/owner/business", headers=owner, json={**NEW_BUSINESS, "use_template": False}).json()
    me = business["specialists"][0]["id"]

    r = client.post("/owner/services", headers=owner, json={"name": "Татуировка", "duration_min": 120, "price": 5000})
    assert r.status_code == 201, r.text
    tattoo = r.json()["services"][0]
    assert tattoo["specialist_ids"] == [me] and tattoo["price"] == 5000
    assert client.post("/owner/services", headers=owner, json={"name": "Эскиз", "duration_min": 45, "price": 0}).status_code == 400
    assert client.post("/owner/services", headers=owner, json={"name": "Э", "duration_min": 30, "price": 0}).status_code == 422

    business = client.post("/owner/specialists", headers=owner, json={"name": "Тимур Мастер", "title": "Тату-мастер"}).json()
    timur = next(sp["id"] for sp in business["specialists"] if sp["name"] == "Тимур Мастер")
    assert sorted(business["services"][0]["specialist_ids"]) == sorted([me, timur])  # performs everything by default

    business = client.patch(f"/owner/services/{tattoo['id']}", headers=owner, json={
        "name": "Татуировка большая", "duration_min": 180, "price": 9000, "specialist_ids": [timur],
    }).json()
    assert business["services"][0] == {
        "id": tattoo["id"], "name": "Татуировка большая", "description": "", "duration_min": 180, "price": 9000,
        "specialist_ids": [timur],
    }
    assert client.patch(f"/owner/services/{tattoo['id']}", headers=owner, json={
        "name": "Татуировка", "duration_min": 60, "price": 1, "specialist_ids": [99999],
    }).status_code == 400
    business = client.patch(f"/owner/specialists/{timur}", headers=owner, json={"name": "Тимур", "title": "Мастер"}).json()
    assert {"id": timur, "name": "Тимур", "title": "Мастер"} in business["specialists"]

    # another owner cannot touch them
    stranger = api.register(role="owner")
    client.post("/owner/business", headers=stranger, json={**NEW_BUSINESS, "name": "Другой салон"})
    assert client.patch(f"/owner/services/{tattoo['id']}", headers=stranger, json={"name": "Взлом", "duration_min": 30, "price": 1}).status_code == 400
    assert client.delete(f"/owner/specialists/{timur}", headers=stranger).status_code == 400

    # a specialist with future bookings cannot be removed; the only one cannot be removed either
    customer = api.register()
    slot = api.slots(business, business["services"][0])[0]
    assert slot["specialist_id"] == timur and slot["duration_min"] == 180
    booked = api.book(customer, slot).json()
    assert client.delete(f"/owner/specialists/{timur}", headers=owner).status_code == 400
    client.patch(f"/owner/appointments/{booked['id']}", headers=owner, json={"status": "cancelled"})
    business = client.delete(f"/owner/specialists/{timur}", headers=owner).json()
    assert [sp["id"] for sp in business["specialists"]] == [me]
    assert client.delete(f"/owner/specialists/{me}", headers=owner).status_code == 400
    assert business["services"][0]["specialist_ids"] == []  # nobody performs it now, so it has no slots
    assert api.slots(business, business["services"][0]) == []
    business = client.delete(f"/owner/services/{tattoo['id']}", headers=owner).json()
    assert business["services"] == []


def test_new_service_is_bookable_by_chat_at_once(client, api):
    owner = api.register(role="owner", name="Айгерим")
    client.post("/owner/business", headers=owner, json={**NEW_BUSINESS, "use_template": False})
    client.post("/owner/services", headers=owner, json={"name": "Татуировка", "duration_min": 120, "price": 5000})
    result = api.chat(api.register(), "хочу татуировку на завтра")
    assert {s["service_name"] for s in result["slots"]} == {"Татуировка"}
    assert "«Татуировка» в «Тату-студия Ink» — 5 000 сом, 120 мин" in result["reply"]
    assert {s["business_name"] for s in api.chat(api.register(), "запишите в Ink")["slots"]} == {"Тату-студия Ink"}


def test_agenda_statuses_manual_booking_and_stats(client, api):
    owner = api.register(role="owner", name="Айгерим")
    business = client.post("/owner/business", headers=owner, json={**NEW_BUSINESS, "working_days": [0, 1, 2, 3, 4, 5, 6]}).json()
    brows = next(s for s in business["services"] if s["name"] == "Оформление бровей")  # 30 min, 500
    lashes = next(s for s in business["services"] if s["name"] == "Наращивание ресниц")  # 120 min, 2000
    day = (clock.now().date() + timedelta(days=1)).isoformat()
    slots = api.slots(business, brows, date=day)

    # a client books through the chat, another through the catalog, the owner types in a walk-in
    by_chat = api.book(api.register(name="Алина"), slots[0], source="chat").json()
    by_app = api.book(api.register(name="Чолпон"), slots[2]).json()
    r = client.post("/owner/appointments", headers=owner, json={
        "service_id": lashes["id"], "start": slots[4]["start"], "client_name": "Гульзат", "client_phone": "+996 555 123 456",
    })
    assert r.status_code == 201, r.text
    walk_in = r.json()
    assert walk_in["source"] == "owner" and walk_in["client_name"] == "Гульзат" and walk_in["price"] == 2000
    assert client.post("/owner/appointments", headers=owner, json={
        "service_id": lashes["id"], "start": slots[5]["start"], "client_name": "Занято",
    }).status_code == 400  # the only specialist is busy
    smile = api.business("Стоматология Smile")
    assert client.post("/owner/appointments", headers=owner, json={
        "service_id": smile["services"][0]["id"], "start": slots[10]["start"], "client_name": "Чужая услуга",
    }).status_code == 400

    agenda = client.get(f"/owner/appointments?date={day}", headers=owner).json()
    assert [(a["client_name"], a["source"]) for a in agenda] == [("Алина", "chat"), ("Чолпон", "app"), ("Гульзат", "owner")]
    assert client.get("/owner/appointments", headers=owner).json() == []  # nothing today

    # statuses
    assert client.patch(f"/owner/appointments/{by_app['id']}", headers=owner, json={"status": "cancelled"}).json()["status"] == "cancelled"
    assert client.patch(f"/owner/appointments/{by_chat['id']}", headers=owner, json={"status": "completed"}).json()["status"] == "completed"
    assert client.patch(f"/owner/appointments/{by_chat['id']}", headers=owner, json={"status": "paid"}).status_code == 422
    stranger = api.register(role="owner")
    client.post("/owner/business", headers=stranger, json={**NEW_BUSINESS, "name": "Другой салон"})
    assert client.patch(f"/owner/appointments/{by_chat['id']}", headers=stranger, json={"status": "no_show"}).status_code == 400
    # restoring a cancelled booking is refused when the time has been taken meanwhile
    again = api.book(api.register(name="Айжан"), slots[2]).json()
    assert client.patch(f"/owner/appointments/{by_app['id']}", headers=owner, json={"status": "booked"}).status_code == 400
    client.patch(f"/owner/appointments/{again['id']}", headers=owner, json={"status": "cancelled"})
    assert client.patch(f"/owner/appointments/{by_app['id']}", headers=owner, json={"status": "booked"}).json()["status"] == "booked"

    stats = client.get("/owner/stats?days=7", headers=owner).json()
    assert stats["upcoming"] == 2 and stats["today_count"] == 0 and stats["bookings"] == 0  # all of it is tomorrow
    assert len(stats["by_day"]) == 7 and stats["by_day"][-1]["date"] == clock.now().date().isoformat()
    assert stats["rating"] is None and stats["today"] == []


def test_stats_count_the_past_week(client, api, monkeypatch):
    owner = api.register(role="owner", name="Айгерим")
    business = client.post("/owner/business", headers=owner, json={**NEW_BUSINESS, "working_days": [0, 1, 2, 3, 4, 5, 6]}).json()
    brows = next(s for s in business["services"] if s["name"] == "Оформление бровей")
    day = (clock.now().date() + timedelta(days=1)).isoformat()
    slots = api.slots(business, brows, date=day)
    ids = [api.book(api.register(), slots[i], source="chat" if i < 2 else "app").json()["id"] for i in (0, 1, 2, 3)]
    client.patch(f"/owner/appointments/{ids[1]}", headers=owner, json={"status": "cancelled"})

    # two days later the owner closes the visits and opens the dashboard
    real_now = clock.now
    monkeypatch.setattr(clock, "now", lambda: real_now() + timedelta(days=2))
    client.patch(f"/owner/appointments/{ids[0]}", headers=owner, json={"status": "completed"})
    client.patch(f"/owner/appointments/{ids[3]}", headers=owner, json={"status": "no_show"})
    stats = client.get("/owner/stats", headers=owner).json()
    assert stats["bookings"] == 3 and stats["completed"] == 1 and stats["cancelled"] == 1 and stats["no_show"] == 1
    assert stats["revenue"] == 1000 and stats["ai_bookings"] == 1 and stats["clients"] == 3
    assert stats["top_services"] == [{"name": "Оформление бровей", "count": 2, "revenue": 1000}]
    assert [d["count"] for d in stats["by_day"]][-2] == 2 and stats["upcoming"] == 0
    assert stats["today_count"] == 0 and stats["load_percent"] == 0


def test_paused_business_is_hidden(client, api):
    owner = api.register(role="owner", name="Айгерим")
    business = client.post("/owner/business", headers=owner, json=NEW_BUSINESS).json()
    paused = client.patch("/owner/business", headers=owner, json={"is_active": False, "name": "Ink Studio", "close_hour": 22}).json()
    assert paused["is_active"] is False and paused["name"] == "Ink Studio" and paused["close_hour"] == 22
    assert business["id"] not in [b["id"] for b in client.get("/businesses").json()]
    assert client.get(f"/businesses/{business['id']}").status_code == 404
    assert api.slots(business, business["services"][0]) == []
    assert api.chat(api.register(), "запишите в Ink Studio")["slots"] == []
    assert client.get("/owner/business", headers=owner).json()["name"] == "Ink Studio"  # the owner still sees it
    assert client.patch("/owner/business", headers=owner, json={"open_hour": 23, "close_hour": 22}).status_code == 400
    assert client.patch("/owner/business", headers=owner, json={"is_active": True}).json()["is_active"] is True


def test_demo_history_is_believable(client, monkeypatch):
    """The demo owner opens a dashboard with visits, and nobody visits the same place twice a day."""
    monkeypatch.setenv("SEED_HISTORY", "1")
    seed.ensure_seed(dbmod.reset_db(drop=True))
    owner = {"Authorization": f"Bearer {client.post('/auth/demo', json={'role': 'owner'}).json()['token']}"}
    stats = client.get("/owner/stats", headers=owner).json()
    assert stats["bookings"] > 0 and stats["reviews_count"] > 0
    total = 0
    for offset in range(-14, 3):
        day = (clock.now().date() + timedelta(days=offset)).isoformat()
        visits = client.get("/owner/appointments", headers=owner, params={"date": day}).json()
        people = [v["client_name"] for v in visits]
        assert all(people) and len(people) == len(set(people)), (day, people)
        total += len(visits)
    assert total >= 10
