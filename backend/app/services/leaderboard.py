from __future__ import annotations

from datetime import date, datetime, timezone
from random import Random

_FIRST = (
    "Alex",
    "Michael",
    "Daniel",
    "Ryan",
    "Chris",
    "James",
    "Ethan",
    "Noah",
    "Liam",
    "Mason",
    "Logan",
    "Lucas",
    "Henry",
    "Owen",
    "Caleb",
    "Nathan",
    "Adrian",
    "Julian",
    "Sebastian",
    "Isaac",
    "Sofia",
    "Emma",
    "Olivia",
    "Ava",
    "Mia",
    "Isabella",
    "Amelia",
    "Harper",
    "Evelyn",
    "Camila",
    "Aria",
    "Scarlett",
    "Penelope",
    "Chloe",
    "Layla",
    "Riley",
    "Zoey",
    "Nora",
    "Hannah",
    "Grace",
)
_LAST = (
    "Walker",
    "Brooks",
    "Reed",
    "Hayes",
    "Cole",
    "Bennett",
    "Foster",
    "Griffin",
    "Ellis",
    "Porter",
    "Sutton",
    "Blake",
    "Warren",
    "Nash",
    "Quinn",
    "Paige",
    "Dean",
    "Holt",
    "Lane",
    "West",
)


def _parse_day(raw: str | None) -> date:
    if raw is None or not raw.strip():
        return datetime.now(timezone.utc).date()
    try:
        return date.fromisoformat(raw.strip())
    except ValueError as exc:
        raise ValueError("Invalid leaderboard day") from exc


def _amount(rng: Random) -> int:
    value = rng.randint(1000, 1_000_000)
    if value % 1000 == 0 and rng.random() < 0.7:
        value = min(1_000_000, value + rng.randint(17, 863))
    return value


def build_daily_leaderboard(day: str | None = None) -> dict:
    selected = _parse_day(day)
    rng = Random(f"tradepulse-daily-leaderboard|{selected.isoformat()}")
    rows = []
    used_names: set[str] = set()
    while len(rows) < 100:
        name = f"{rng.choice(_FIRST)} {rng.choice(_LAST)}"
        if name in used_names:
            name = f"{name} {rng.randint(2, 99)}"
        used_names.add(name)
        rows.append({"name": name, "todays_win": _amount(rng)})
    rows.sort(key=lambda item: (-item["todays_win"], item["name"]))
    entries = [
        {"rank": index + 1, "name": item["name"], "todays_win": item["todays_win"]}
        for index, item in enumerate(rows)
    ]
    return {
        "title": "Leaderboard",
        "badge": "TOP 100",
        "day": selected.isoformat(),
        "entries": entries,
    }
