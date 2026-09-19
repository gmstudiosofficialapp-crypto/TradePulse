"""PostgreSQL-ready persistence. Runtime currently uses in-memory stores."""

from __future__ import annotations


class PostgresStore:
    def __init__(self, dsn: str | None = None) -> None:
        self.dsn = dsn

    def connect(self) -> None:
        raise NotImplementedError(
            "PostgreSQL adapter is prepared but not required for Phase 3 demo."
        )
