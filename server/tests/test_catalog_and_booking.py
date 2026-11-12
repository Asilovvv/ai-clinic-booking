from datetime import datetime, timedelta

from app import clock
from app import db as dbmod
from app.db import appointments


def test_register_login_roles_and_demo(client, api):
    api.register()
    assert client.post("/auth/register", json={"name": "Xx", "email": "user1@test.kg", "password": "secret1"}).status_code == 409
    assert client.post("/auth/login", json={"email": "user1@test.kg", "password": "wrong"}).status_code == 401
    token = client.post("/auth/login", json={"email": "USER1@test.kg", "password": "secret1"}).json()["token"]
    me = client.get("/me", headers={"Authorization": f"Bearer {token}"}).json()
    assert me["name"] == "Бектур" and me["role"] == "customer"
    assert client.get("/me").status_code == 401

    owner = client.post("/auth/demo", json={"role": "owner"}).json()
    assert owner["user"]["role"] == "owner"
    assert client.post("/auth/demo", json={"role": "customer"}).json()["user"]["role"] == "customer"
    assert client.get("/config").json()["demo"] is True
    # accounts created for demo history cannot sign in
    assert client.post("/auth/login", json={"email": "partners@smile.local", "password": "!"}).status_code == 401


def test_catalog(client, api):
    categories = client.get("/categories").json()
    assert len(categories) == 10 and categories[0]["id"] == "dental"
    everything = client.get("/businesses").json()
    assert len(everything) == 12
    assert {b["category"] for b in everything} == {c["id"] for c in categories}
    barbers = client.get("/businesses?category=barber").json()
    assert sorted(b["name"] for b in barbers) == ["Barber House", "Барбершоп Blade"]

    smile = api.business("Стоматология Smile")
    assert len(smile["services"]) == 7 and len(smile["specialists"]) == 5
    assert smile["price_from"] == 500 and smile["working_days"] == [0, 1, 2, 3, 4, 5]
    assert "чистка" in smile["search_text"]
    cleaning = api.service(smile, "Профессиональная чистка зубов")
    assert cleaning["duration_min"] == 60 and len(cleaning["specialist_ids"]) == 1
    assert client.get("/businesses/9999").status_code == 404
    # a cheaper competitor has rounded prices from the same template
    assert api.service(api.business("Barber House"), "Мужская стрижка")["price"] == 500


def test_slots_follow_hours_and_duration(client, api):
    smile = api.business("Стоматология Smile")
    whitening = api.service(smile, "Отбеливание зубов")  # 90 minutes, open 9-18
    day = api.slots(smile, whitening)[0]["start"][:10]
    slots = api.slots(smile, whitening, date=day)
    assert slots and all(s["start"].startswith(day) for s in slots)
    starts = [s["start"][11:] for s in slots]
    assert starts == sorted(set(starts))
    assert all(t[3:] in ("00", "30") for t in starts)
    assert starts[-1] == "16:30"  # the last start that still ends by closing time
    assert datetime.strptime(slots[0]["start"], clock.FMT).weekday() != 6  # closed on Sunday
    assert slots[0]["price"] == 6000 and slots[0]["business_name"] == "Стоматология Smile"
    assert client.get(f"/businesses/{smile['id']}/slots?service_id={whitening['id']}&date=bad").status_code == 400
    assert api.slots(smile, whitening, date="2020-01-01") == []


def test_booking_rules(client, api):
    first, second = api.register(), api.register()
    smile = api.business("Стоматология Smile")
    cleaning = api.service(smile, "Профессиональная чистка зубов")  # one hygienist, 60 minutes
    slots = api.full_day(smile, cleaning)
    slot = slots[2]
    r = api.book(first, slot)
    assert r.status_code == 201, r.text
    booked = r.json()
    assert booked["status"] == "booked" and booked["upcoming"] is True and booked["price"] == 2000
    assert booked["end"] == (datetime.strptime(slot["start"], clock.FMT) + timedelta(minutes=60)).strftime(clock.FMT)

    # the same specialist is busy for the whole hour, also for a start 30 minutes earlier or later
    assert api.book(second, slot).status_code == 400
    assert api.book(second, slots[1]).status_code == 400
    assert api.book(second, slots[3]).status_code == 400
    free = [s["start"] for s in api.slots(smile, cleaning, date=slot["start"][:10])]
    assert all(s["start"] not in free for s in slots[1:4]) and slots[4]["start"] in free

    # one client cannot be in two places at once
    aurora = api.business("Салон красоты Aurora")
    brows = api.service(aurora, "Оформление бровей")
    clash = {"service_id": brows["id"], "specialist_id": brows["specialist_ids"][0], "start": slot["start"]}
    assert client.post("/appointments", headers=first, json=clash).status_code == 400
    assert client.post("/appointments", headers=second, json=clash).status_code == 201

    # invalid requests
    assert client.post("/appointments", headers=first, json={"service_id": 9999, "start": slot["start"]}).status_code == 400
    assert client.post("/appointments", headers=first, json={**clash, "start": "2020-01-01T10:00"}).status_code == 400
    assert client.post("/appointments", headers=first, json={**clash, "start": slot["start"][:14] + "15"}).status_code == 400
    assert client.post("/appointments", json=clash).status_code == 401

    # cancelling frees the time and keeps the record
    assert client.delete(f"/appointments/{booked['id']}", headers=second).status_code == 400
    assert client.delete(f"/appointments/{booked['id']}", headers=first).json()["status"] == "cancelled"
    assert slot["start"] in [s["start"] for s in api.slots(smile, cleaning, date=slot["start"][:10])]
    mine = client.get("/appointments", headers=first).json()
    assert [a["status"] for a in mine] == ["cancelled"] and mine[0]["upcoming"] is False


def test_any_specialist_takes_the_free_one(client, api):
    smile = api.business("Стоматология Smile")
    consult = api.service(smile, "Консультация и осмотр")  # two doctors perform it
    assert len(consult["specialist_ids"]) == 2
    start = api.slots(smile, consult)[0]["start"]
    taken = []
    for _ in range(2):
        r = client.post("/appointments", headers=api.register(), json={"service_id": consult["id"], "start": start})
        assert r.status_code == 201, r.text
        taken.append(r.json()["specialist_id"])
    assert sorted(taken) == sorted(consult["specialist_ids"])
    r = client.post("/appointments", headers=api.register(), json={"service_id": consult["id"], "start": start})
    assert r.status_code == 400 and "занято" in r.json()["detail"]
    assert start not in [s["start"] for s in api.slots(smile, consult)]


def test_reschedule(client, api):
    first, second = api.register(), api.register()
    blade = api.business("Барбершоп Blade")
    beard = api.service(blade, "Оформление бороды")
    slots = api.full_day(blade, beard)
    booked = api.book(first, slots[0]).json()
    moved = client.patch(f"/appointments/{booked['id']}", headers=first, json={"start": slots[4]["start"]})
    assert moved.status_code == 200 and moved.json()["start"] == slots[4]["start"]
    free = [s["start"] for s in api.slots(blade, beard, date=slots[0]["start"][:10])]
    assert slots[0]["start"] in free and slots[4]["start"] not in free
    assert client.patch(f"/appointments/{booked['id']}", headers=second, json={"start": slots[5]["start"]}).status_code == 400
    other = api.book(second, slots[5]).json()
    assert client.patch(f"/appointments/{booked['id']}", headers=first, json={"start": other["start"]}).status_code == 400


def test_moving_a_booking_frees_its_own_time_for_its_client_only(client, api):
    first, second = api.register(), api.register()
    blade = api.business("Барбершоп Blade")
    cut = api.service(blade, "Мужская стрижка")  # 60 minutes
    slots = api.full_day(blade, cut)
    booked = api.book(first, slots[2]).json()
    day = booked["start"][:10]

    def free(headers=None, **params):
        r = client.get(f"/businesses/{blade['id']}/slots", headers=headers, params={
            "service_id": cut["id"], "specialist_id": booked["specialist_id"], "date": day, **params,
        })
        assert r.status_code == 200, r.text
        return [s["start"] for s in r.json()]

    # The booking blocks its own start and the half-hours it overlaps.
    assert booked["start"] not in free(first)
    assert slots[1]["start"] not in free(first)
    # Its client may move it by half an hour: the booking's own time counts as free.
    mine = free(first, exclude_appointment_id=booked["id"])
    assert booked["start"] in mine and slots[1]["start"] in mine
    # Nobody else gets that, signed in or not.
    assert booked["start"] not in free(second, exclude_appointment_id=booked["id"])
    assert booked["start"] not in free(exclude_appointment_id=booked["id"])

    moved = client.patch(f"/appointments/{booked['id']}", headers=first, json={"start": slots[1]["start"]})
    assert moved.status_code == 200 and moved.json()["start"] == slots[1]["start"]


def test_review_after_visit(client, api):
    headers = api.register()
    me = client.get("/me", headers=headers).json()
    blade = api.business("Барбершоп Blade")
    cut = api.service(blade, "Мужская стрижка")
    start = clock.now().replace(minute=0) - timedelta(days=1)
    visit = dbmod.get_db().insert(
        appointments, business_id=blade["id"], service_id=cut["id"], specialist_id=cut["specialist_ids"][0],
        customer_id=me["id"], starts_at=start.strftime(clock.FMT),
        ends_at=(start + timedelta(hours=1)).strftime(clock.FMT), duration_min=60, price=600,
        status="booked", source="app", note="", created_at=clock.stamp(),
    )
    upcoming = api.book(headers, api.slots(blade, cut)[0]).json()
    history = {a["id"]: a for a in client.get("/appointments", headers=headers).json()}
    assert history[visit]["can_review"] is True and history[visit]["upcoming"] is False
    assert history[upcoming["id"]]["can_review"] is False

    assert client.post(f"/appointments/{upcoming['id']}/review", headers=headers, json={"rating": 5}).status_code == 400
    assert client.post(f"/appointments/{visit}/review", headers=headers, json={"rating": 6}).status_code == 422
    done = client.post(f"/appointments/{visit}/review", headers=headers, json={"rating": 5, "comment": "Отлично"})
    assert done.status_code == 200 and done.json()["review"] == {"rating": 5, "comment": "Отлично"}
    assert client.post(f"/appointments/{visit}/review", headers=headers, json={"rating": 4}).status_code == 400
    assert client.post(f"/appointments/{visit}/review", headers=api.register(), json={"rating": 1}).status_code == 400

    blade = api.business("Барбершоп Blade")
    assert blade["rating"] == 5.0 and blade["reviews_count"] == 1
    assert blade["reviews"][0]["author"] == "Бектур" and blade["reviews"][0]["comment"] == "Отлично"
    # rated businesses come first in the catalog
    assert client.get("/businesses").json()[0]["name"] == "Барбершоп Blade"
