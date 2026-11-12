"""One clock for the whole server: business local time (Asia/Bishkek by default)."""
import os
from datetime import datetime
from zoneinfo import ZoneInfo

TZ = ZoneInfo(os.getenv("APP_TIMEZONE", "Asia/Bishkek"))
FMT = "%Y-%m-%dT%H:%M"


def now() -> datetime:
    """Current local time without seconds and without tzinfo."""
    return datetime.now(TZ).replace(tzinfo=None, second=0, microsecond=0)


def stamp(moment: datetime | None = None) -> str:
    return (moment or now()).strftime(FMT)
