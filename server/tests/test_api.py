import os

import pytest
from fastapi.testclient import TestClient

from app import db as dbmod
from app.main import app


@pytest.fixture()
def client(tmp_path, monkeypatch):
    monkeypatch.delenv("LLM_API_KEY", raising=False)
    dbmod.reset_db(str(tmp_path / "test.db"))
    return TestClient(app)


def register(client, email="a@test.kg"):
    r = client.post("/auth/register", json={"name": "Бектур", "email": email, "password": "secret1"})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['token']}"}


def test_register_login_me(client):
    register(client)
    assert client.post("/auth/register", json={"name": "Xx", "email": "a@test.kg", "password": "secret1"}).status_code == 409
    assert client.post("/auth/login", json={"email": "a@test.kg", "password": "wrong"}).status_code == 401
    r = client.post("/auth/login", json={"email": "A@test.kg", "password": "secret1"})
    assert r.status_code == 200
    me = client.get("/me", headers={"Authorization": f"Bearer {r.json()['token']}"})
    assert me.json()["name"] == "Бектур"
    assert client.get("/me").status_code == 401


def test_booking_flow(client):
    h = register(client)
    assert len(client.get("/doctors").json()) == 11
    assert len(client.get("/doctors?category=dental").json()) == 5
    assert [c["id"] for c in client.get("/categories").json()] == ["dental", "barber", "auto"]
    slots = client.get("/doctors/1/slots").json()
    assert slots
    slot = slots[0]
    r = client.post("/appointments", json={"doctor_id": 1, "start": slot["start"]}, headers=h)
    assert r.status_code == 201, r.text
    # same slot cannot be booked twice, even by another user
    h2 = register(client, "b@test.kg")
    assert client.post("/appointments", json={"doctor_id": 1, "start": slot["start"]}, headers=h2).status_code == 400
    assert slot["start"] not in [s["start"] for s in client.get("/doctors/1/slots").json()]
    appts = client.get("/appointments", headers=h).json()
    assert len(appts) == 1
    # another user cannot cancel it
    assert client.delete(f"/appointments/{appts[0]['id']}", headers=h2).status_code == 404
    assert client.delete(f"/appointments/{appts[0]['id']}", headers=h).status_code == 204
    assert client.get("/appointments", headers=h).json() == []


def test_booking_rejects_closed_hours(client):
    h = register(client)
    r = client.post("/appointments", json={"doctor_id": 1, "start": "2020-01-01T10:00"}, headers=h)
    assert r.status_code == 400


def test_chat_rules_mode_finds_slots(client):
    h = register(client)
    r = client.post("/chat", json={"message": "Болит зуб, хочу записаться после обеда", "history": []}, headers=h)
    body = r.json()
    assert body["mode"] == "rules"
    assert body["slots"]
    assert all(s["doctor_id"] == 1 for s in body["slots"])  # therapist
    assert all(int(s["start"][11:13]) >= 13 for s in body["slots"])


def test_chat_rules_greeting_and_my_appointments(client):
    h = register(client)
    greet = client.post("/chat", json={"message": "привет"}, headers=h).json()
    assert "ИИ-администратор" in greet["reply"] and greet["slots"] == []
    mine = client.post("/chat", json={"message": "покажи мои записи"}, headers=h).json()
    assert "нет записей" in mine["reply"]


def test_chat_falls_back_when_llm_fails(client, monkeypatch):
    monkeypatch.setenv("LLM_API_KEY", "bad")
    monkeypatch.setenv("LLM_BASE_URL", "http://127.0.0.1:9")  # nothing listens here
    h = register(client)
    body = client.post("/chat", json={"message": "чистка в субботу утром"}, headers=h).json()
    assert body["mode"] == "rules"
    assert all(s["doctor_id"] == 4 for s in body["slots"])


def test_chat_ai_mode_tool_calling(client, monkeypatch):
    """Simulate an LLM that searches slots, then books the first one."""
    import json as _json

    import httpx

    from app import assistant

    calls = {"n": 0}

    def handler(request: httpx.Request) -> httpx.Response:
        calls["n"] += 1
        msgs = _json.loads(request.content)["messages"]
        if calls["n"] == 1:
            tc = [{"id": "c1", "type": "function", "function": {"name": "find_slots",
                   "arguments": _json.dumps({"category": "dental", "specialty": "surgeon", "part_of_day": "any"})}}]
            return httpx.Response(200, json={"choices": [{"message": {"content": None, "tool_calls": tc}}]})
        if calls["n"] == 2:
            slots = _json.loads(msgs[-1]["content"])
            tc = [{"id": "c2", "type": "function", "function": {"name": "book_appointment",
                   "arguments": _json.dumps({"doctor_id": slots[0]["doctor_id"], "start": slots[0]["start"]})}}]
            return httpx.Response(200, json={"choices": [{"message": {"content": None, "tool_calls": tc}}]})
        return httpx.Response(200, json={"choices": [{"message": {"content": "Записал вас к хирургу."}}]})

    real_client = httpx.Client
    monkeypatch.setattr(assistant.httpx, "Client", lambda **kw: real_client(transport=httpx.MockTransport(handler)))
    monkeypatch.setenv("LLM_API_KEY", "test")
    h = register(client)
    body = client.post("/chat", json={"message": "удалить зуб, запиши на ближайшее"}, headers=h).json()
    assert body["mode"] == "ai"
    assert body["reply"] == "Записал вас к хирургу."
    assert body["appointment"]["doctor_id"] == 2
    assert len(client.get("/appointments", headers=h).json()) == 1


def chat(client, h, message, category=None):
    r = client.post("/chat", json={"message": message, "category": category}, headers=h)
    assert r.status_code == 200, r.text
    return r.json()


def test_chat_other_businesses(client):
    h = register(client)
    barber = chat(client, h, "хочу стрижку завтра")
    assert barber["slots"] and all(s["doctor_id"] == 6 for s in barber["slots"])
    auto = chat(client, h, "замена масла в машине")
    assert auto["slots"] and all(s["doctor_id"] == 9 for s in auto["slots"])
    # a selected category limits the search when no specialty is named
    any_auto = chat(client, h, "запишите на ближайшее время", category="auto")
    assert any_auto["slots"] and all(s["category"] == "auto" for s in any_auto["slots"])


def test_reschedule_and_cancel_via_chat(client):
    h = register(client)
    slot = chat(client, h, "стрижка")["slots"][0]
    appt = client.post("/appointments", json={"doctor_id": slot["doctor_id"], "start": slot["start"]}, headers=h).json()

    offer = chat(client, h, "перенеси мою запись")
    assert offer["reschedule_id"] == appt["id"]
    assert all(s["doctor_id"] == slot["doctor_id"] for s in offer["slots"])
    new_start = offer["slots"][0]["start"]
    assert new_start != slot["start"]
    moved = client.patch(f"/appointments/{appt['id']}", json={"start": new_start}, headers=h)
    assert moved.status_code == 200 and moved.json()["start"] == new_start
    # the old time is free again
    assert slot["start"] in [s["start"] for s in client.get(f"/doctors/{slot['doctor_id']}/slots").json()]

    cancelled = chat(client, h, "отмени запись")
    assert cancelled["changed"] is True
    assert client.get("/appointments", headers=h).json() == []


def test_cancel_via_chat_asks_when_ambiguous(client):
    h = register(client)
    for i, text in enumerate(["стрижка", "диагностика авто"]):
        s = chat(client, h, text)["slots"][i]  # different hours: one client, one place at a time
        assert client.post("/appointments", json={"doctor_id": s["doctor_id"], "start": s["start"]}, headers=h).status_code == 201
    unclear = chat(client, h, "отмени запись")
    assert unclear["changed"] is False and "Уточните" in unclear["reply"]
    assert len(client.get("/appointments", headers=h).json()) == 2
    done = chat(client, h, "отмени запись в автосервис")
    assert done["changed"] is True
    left = client.get("/appointments", headers=h).json()
    assert len(left) == 1 and left[0]["category"] == "barber"


def test_reschedule_rejects_taken_slot(client):
    h = register(client)
    slots = client.get("/doctors/1/slots").json()
    a = client.post("/appointments", json={"doctor_id": 1, "start": slots[0]["start"]}, headers=h).json()
    h2 = register(client, "b@test.kg")
    client.post("/appointments", json={"doctor_id": 1, "start": slots[1]["start"]}, headers=h2)
    assert client.patch(f"/appointments/{a['id']}", json={"start": slots[1]["start"]}, headers=h).status_code == 400
    assert client.patch(f"/appointments/{a['id']}", json={"start": slots[2]["start"]}, headers=h2).status_code == 404


def test_chat_for_specific_specialist(client):
    h = register(client)
    r = client.post("/chat", json={"message": "Хочу записаться", "doctor_id": 7}, headers=h).json()
    assert r["slots"] and all(s["doctor_id"] == 7 for s in r["slots"])
