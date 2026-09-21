from __future__ import annotations

import json
import time
from collections.abc import Callable
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from app.state import BtcFutureState

BACKOFF = (1.0, 2.0, 5.0, 15.0)


class TradePulseSignalClient:
    def __init__(self, base_url: str, token: str) -> None:
        self.base_url = base_url.rstrip("/")
        self.token = token
        self.state = BtcFutureState()

    def snapshot_url(self) -> str:
        return f"{self.base_url}/api/signal/btc-future-book"

    def ws_url(self) -> str:
        root = self.base_url.replace("https://", "wss://").replace("http://", "ws://")
        return f"{root}/ws/signal-btc-future"

    def headers(self) -> dict[str, str]:
        return {"Authorization": f"Bearer {self.token}"}

    def fetch_snapshot(self) -> dict:
        request = Request(self.snapshot_url(), headers=self.headers())
        with urlopen(request, timeout=15) as response:
            payload = json.loads(response.read().decode("utf-8"))
        if not self.state.apply(payload, allow_snapshot_reset=True):
            raise ValueError(self.state.last_error or "invalid snapshot")
        return payload

    def apply_message(self, message: dict) -> bool:
        return self.state.apply(message)

    def reconnect_delay(self, attempt: int) -> float:
        return BACKOFF[min(attempt, len(BACKOFF) - 1)]

    def resync_with_retry(self, sleep: Callable[[float], None] = time.sleep) -> dict:
        last_error: Exception | None = None
        for attempt in range(len(BACKOFF)):
            try:
                self.state.mark_connected(True)
                return self.fetch_snapshot()
            except (HTTPError, URLError, TimeoutError, ValueError) as exc:
                last_error = exc
                self.state.mark_connected(False)
                self.state.last_error = str(exc)
                sleep(self.reconnect_delay(attempt))
        raise RuntimeError(f"resync failed: {last_error}")
