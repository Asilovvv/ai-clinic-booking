"""SQLite storage: schema, seed data and small query helpers."""
import os
import sqlite3
import threading

DOCTORS = [
    (1, "Айгуль Садыкова", "therapist", "Терапевт-стоматолог", "Лечение кариеса, пломбы, боль в зубе"),
    (2, "Нурлан Абдыкадыров", "surgeon", "Хирург-имплантолог", "Удаление зубов, импланты"),
    (3, "Элина Ким", "orthodontist", "Ортодонт", "Брекеты, элайнеры, прикус"),
    (4, "Бакыт Осмонов", "hygienist", "Гигиенист", "Профчистка, отбеливание"),
    (5, "Мира Токтогулова", "pediatric", "Детский стоматолог", "Лечение зубов у детей"),
]

SCHEMA = """
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS tokens (
    token TEXT PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id)
);
CREATE TABLE IF NOT EXISTS doctors (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    specialty TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS appointments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id),
    doctor_id INTEGER NOT NULL REFERENCES doctors(id),
    start TEXT NOT NULL,
    UNIQUE (doctor_id, start)
);
"""


class Database:
    """Thread-safe wrapper around a single SQLite connection."""

    def __init__(self, path: str):
        self.conn = sqlite3.connect(path, check_same_thread=False)
        self.conn.row_factory = sqlite3.Row
        self.lock = threading.Lock()
        with self.lock:
            self.conn.executescript(SCHEMA)
            self.conn.executemany(
                "INSERT OR IGNORE INTO doctors (id, name, specialty, title, description) VALUES (?, ?, ?, ?, ?)",
                DOCTORS,
            )
            self.conn.commit()

    def query(self, sql: str, params: tuple = ()) -> list[dict]:
        with self.lock:
            return [dict(r) for r in self.conn.execute(sql, params).fetchall()]

    def one(self, sql: str, params: tuple = ()) -> dict | None:
        rows = self.query(sql, params)
        return rows[0] if rows else None

    def execute(self, sql: str, params: tuple = ()) -> int:
        """Run a write statement and return lastrowid."""
        with self.lock:
            cur = self.conn.execute(sql, params)
            self.conn.commit()
            return cur.lastrowid


_db: Database | None = None


def get_db() -> Database:
    global _db
    if _db is None:
        _db = Database(os.getenv("DB_PATH", "clinic.db"))
    return _db


def reset_db(path: str) -> Database:
    """Used by tests to point the app at a fresh database."""
    global _db
    _db = Database(path)
    return _db
