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
    assert len(client.get("/doctors").json()) == 5
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
                   "arguments": _json.dumps({"specialty": "surgeon", "part_of_day": "any"})}}]
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
