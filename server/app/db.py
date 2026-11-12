"""Database: schema and small query helpers on top of SQLAlchemy Core.

SQLite is used locally and in tests, PostgreSQL in the cloud (set DATABASE_URL).
All queries are plain SQL with named parameters, so both run the same code.
"""
import os
from contextlib import contextmanager

from sqlalchemy import Column, ForeignKey, Index, Integer, MetaData, String, Table, Text, create_engine, text

metadata = MetaData()

users = Table(
    "users", metadata,
    Column("id", Integer, primary_key=True),
    Column("name", String(80), nullable=False),
    Column("email", String(160), nullable=False, unique=True),
    Column("password_hash", String(200), nullable=False),
    Column("role", String(16), nullable=False),  # customer | owner
    Column("phone", String(32)),
    Column("created_at", String(16), nullable=False),
)

tokens = Table(
    "tokens", metadata,
    Column("token", String(64), primary_key=True),
    Column("user_id", Integer, ForeignKey("users.id"), nullable=False),
)

businesses = Table(
    "businesses", metadata,
    Column("id", Integer, primary_key=True),
    Column("owner_id", Integer, ForeignKey("users.id"), nullable=False),
    Column("category", String(24), nullable=False),
    Column("name", String(80), nullable=False),
    Column("description", Text, nullable=False),
    Column("address", String(160), nullable=False),
    Column("phone", String(32), nullable=False),
    Column("open_hour", Integer, nullable=False),
    Column("close_hour", Integer, nullable=False),
    Column("working_days", String(16), nullable=False),  # "0,1,2,3,4,5", Monday is 0
    Column("is_active", Integer, nullable=False),
    Column("created_at", String(16), nullable=False),
)

# A specialist is a person or a resource (for example a wash bay).
specialists = Table(
    "specialists", metadata,
    Column("id", Integer, primary_key=True),
    Column("business_id", Integer, ForeignKey("businesses.id"), nullable=False, index=True),
    Column("name", String(80), nullable=False),
    Column("title", String(80), nullable=False),
    Column("is_active", Integer, nullable=False),
    Column("sort_order", Integer, nullable=False),
)

services = Table(
    "services", metadata,
    Column("id", Integer, primary_key=True),
    Column("business_id", Integer, ForeignKey("businesses.id"), nullable=False, index=True),
    Column("name", String(80), nullable=False),
    Column("description", Text, nullable=False),
    Column("duration_min", Integer, nullable=False),
    Column("price", Integer, nullable=False),
    Column("keywords", Text, nullable=False),  # comma-separated word stems for the assistant
    Column("is_active", Integer, nullable=False),
    Column("sort_order", Integer, nullable=False),
)

specialist_services = Table(
    "specialist_services", metadata,
    Column("specialist_id", Integer, ForeignKey("specialists.id"), primary_key=True),
    Column("service_id", Integer, ForeignKey("services.id"), primary_key=True),
)

appointments = Table(
    "appointments", metadata,
    Column("id", Integer, primary_key=True),
    Column("business_id", Integer, ForeignKey("businesses.id"), nullable=False),
    Column("service_id", Integer, ForeignKey("services.id"), nullable=False),
    Column("specialist_id", Integer, ForeignKey("specialists.id"), nullable=False),
    Column("customer_id", Integer, ForeignKey("users.id")),  # empty for bookings typed in by the owner
    Column("client_name", String(80)),
    Column("client_phone", String(32)),
    Column("starts_at", String(16), nullable=False),  # YYYY-MM-DDTHH:MM, business local time
    Column("ends_at", String(16), nullable=False),
    Column("duration_min", Integer, nullable=False),
    Column("price", Integer, nullable=False),
    Column("status", String(16), nullable=False),  # booked | completed | no_show | cancelled
    Column("source", String(16), nullable=False),  # chat | app | owner
    Column("note", Text, nullable=False),
    Column("created_at", String(16), nullable=False),
)
Index("ix_appointments_specialist", appointments.c.specialist_id, appointments.c.starts_at)
Index("ix_appointments_business", appointments.c.business_id, appointments.c.starts_at)
Index("ix_appointments_customer", appointments.c.customer_id, appointments.c.starts_at)

reviews = Table(
    "reviews", metadata,
    Column("id", Integer, primary_key=True),
    Column("appointment_id", Integer, ForeignKey("appointments.id"), nullable=False, unique=True),
    Column("business_id", Integer, ForeignKey("businesses.id"), nullable=False, index=True),
    Column("customer_id", Integer, ForeignKey("users.id"), nullable=False),
    Column("rating", Integer, nullable=False),
    Column("comment", Text, nullable=False),
    Column("created_at", String(16), nullable=False),
)


def in_params(prefix: str, values) -> tuple[str, dict]:
    """Build "(:p0, :p1)" and its parameters for an IN (...) filter."""
    values = list(values)
    if not values:
        return "(NULL)", {}
    names = [f"{prefix}{i}" for i in range(len(values))]
    return "(" + ", ".join(f":{n}" for n in names) + ")", dict(zip(names, values))


class _Queries:
    """Query helpers shared by Database (one statement per transaction) and Tx."""

    dialect: str

    def _run(self, fn):
        raise NotImplementedError

    def query(self, sql: str, **params) -> list[dict]:
        return self._run(lambda conn: [dict(row) for row in conn.execute(text(sql), params).mappings().all()])

    def one(self, sql: str, **params) -> dict | None:
        rows = self.query(sql, **params)
        return rows[0] if rows else None

    def execute(self, sql: str, **params) -> None:
        def run(conn):
            conn.execute(text(sql), params)

        self._run(run)

    def insert(self, table: Table, **values) -> int:
        """Insert one row and return its first primary key column."""
        return self._run(lambda conn: conn.execute(table.insert().values(**values)).inserted_primary_key[0])


class Tx(_Queries):
    """Several statements inside one transaction."""

    def __init__(self, conn, dialect: str):
        self.conn = conn
        self.dialect = dialect

    def _run(self, fn):
        return fn(self.conn)

    @contextmanager
    def begin(self):
        yield self  # already inside a transaction


class Database(_Queries):
    def __init__(self, url: str):
        options: dict = {"pool_pre_ping": True}
        if url.startswith("sqlite"):
            options["connect_args"] = {"check_same_thread": False}
        else:
            options["pool_recycle"] = 300
            # Cloud databases are usually reached through a pooler (PgBouncer) that hands every
            # transaction to another server connection. A statement prepared on one of them fails
            # on the next ("prepared statement already exists"), so the driver must not prepare.
            options["connect_args"] = {"prepare_threshold": None}
        self.url = url
        self.engine = create_engine(url, **options)
        self.dialect = self.engine.dialect.name
        metadata.create_all(self.engine)

    def _run(self, fn):
        with self.engine.begin() as conn:
            return fn(conn)

    @contextmanager
    def begin(self):
        """Run a block in one transaction: commit at the end, roll back on error."""
        with self.engine.begin() as conn:
            yield Tx(conn, self.dialect)


def database_url() -> str:
    url = os.getenv("DATABASE_URL", "").strip()
    if not url:
        return f"sqlite:///{os.getenv('DB_PATH', 'smile.db')}"
    # Hosting providers hand out postgres:// or postgresql:// addresses.
    if url.startswith("postgres://"):
        url = "postgresql://" + url[len("postgres://"):]
    if url.startswith("postgresql://"):
        url = "postgresql+psycopg://" + url[len("postgresql://"):]
    return url


_db: Database | None = None


def get_db() -> Database:
    global _db
    if _db is None:
        _db = Database(database_url())
    return _db


def reset_db(url: str | None = None, drop: bool = False) -> Database:
    """Point the app at another database (used by tests). `drop` empties it first."""
    global _db
    if _db is not None:
        _db.engine.dispose()
    if drop:
        engine = create_engine(url or database_url())
        metadata.drop_all(engine)
        engine.dispose()
    _db = Database(url or database_url())
    return _db
