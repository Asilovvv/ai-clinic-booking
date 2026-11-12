"""Shared fixtures: every test gets an empty database with the demo businesses."""
import os

import pytest
from fastapi.testclient import TestClient

from app import db as dbmod
from app import seed
from app.main import app


@pytest.fixture()
def client(tmp_path, monkeypatch):
    monkeypatch.delenv("LLM_API_KEY", raising=False)
    monkeypatch.setenv("SEED_DEMO", "1")
    monkeypatch.setenv("SEED_HISTORY", "0")
    # CI also runs the suite on PostgreSQL by setting TEST_DATABASE_URL.
    url = os.getenv("TEST_DATABASE_URL")
    if url:
        monkeypatch.setenv("DATABASE_URL", url)
    else:
        monkeypatch.delenv("DATABASE_URL", raising=False)
        monkeypatch.setenv("DB_PATH", str(tmp_path / "test.db"))
    seed.ensure_seed(dbmod.reset_db(drop=True))
    return TestClient(app)


class Api:
    """Small helpers on top of the test client."""

    def __init__(self, client):
        self.client = client
        self._n = 0

    def register(self, role="customer", name="Бектур"):
        self._n += 1
        r = self.client.post("/auth/register", json={
            "name": name, "email": f"user{self._n}@test.kg", "password": "secret1", "role": role,
        })
        assert r.status_code == 200, r.text
        return {"Authorization": f"Bearer {r.json()['token']}"}

    def business(self, name):
        found = [b for b in self.client.get("/businesses").json() if b["name"] == name]
        assert found, name
        return self.client.get(f"/businesses/{found[0]['id']}").json()

    def service(self, business, name):
        return next(s for s in business["services"] if s["name"] == name)

    def slots(self, business, service, **params):
        r = self.client.get(f"/businesses/{business['id']}/slots", params={"service_id": service["id"], **params})
        assert r.status_code == 200, r.text
        return r.json()

    def full_day(self, business, service):
        """Slots of the first future day that is still completely free."""
        from datetime import timedelta

        from app import clock

        for ahead in range(1, 10):
            day = (clock.now().date() + timedelta(days=ahead)).isoformat()
            slots = self.slots(business, service, date=day)
            if len(slots) >= 8:
                return slots
        raise AssertionError("no free day found")

    def book(self, headers, slot, **extra):
        return self.client.post("/appointments", headers=headers, json={
            "service_id": slot["service_id"], "specialist_id": slot["specialist_id"], "start": slot["start"], **extra,
        })

    def chat(self, headers, message, **scope):
        r = self.client.post("/chat", headers=headers, json={"message": message, **scope})
        assert r.status_code == 200, r.text
        return r.json()


@pytest.fixture()
def api(client):
    return Api(client)
