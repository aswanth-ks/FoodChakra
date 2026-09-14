"""How long the process took to become ready, phase by phase.

Exists to answer one question with evidence instead of guesswork: the first
request to the deployed API after a period of inactivity takes tens of seconds,
and "the backend is slow to wake" does not say *which part* is slow. Everything
before the Python process exists — the platform scheduling and starting a
container — cannot be measured from inside it, but everything after can, and
the difference between the two is the rest of the answer.

Durations only. No connection strings, no credentials, no host names.
"""

from __future__ import annotations

import time
from dataclasses import dataclass, field


@dataclass
class StartupTiming:
    """Milliseconds spent in each phase of becoming ready."""

    #: Wall-clock at the moment this module was first imported, which is as
    #: close to "the Python process started" as the application can see.
    process_started_at: float = field(default_factory=time.monotonic)

    connect_ms: int | None = None
    indexes_ms: int | None = None
    total_ms: int | None = None

    def as_dict(self) -> dict[str, int | None]:
        return {
            "connect_ms": self.connect_ms,
            "indexes_ms": self.indexes_ms,
            "total_ms": self.total_ms,
        }


#: One per process. Populated by the lifespan hook, read by `/health`.
startup_timing = StartupTiming()
