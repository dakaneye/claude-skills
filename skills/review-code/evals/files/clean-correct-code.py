"""Retry utility with exponential backoff for transient HTTP failures."""

from __future__ import annotations

import logging
import time
from collections.abc import Callable
from typing import TypeVar

import httpx

logger = logging.getLogger(__name__)

T = TypeVar("T")

_TRANSIENT_STATUS_CODES = frozenset({429, 502, 503, 504})


def with_retry(
    fn: Callable[[], T],
    *,
    max_attempts: int = 3,
    base_delay: float = 1.0,
    max_delay: float = 30.0,
) -> T:
    """Execute ``fn`` with exponential backoff on transient HTTP errors.

    Args:
        fn: Zero-argument callable that may raise ``httpx.HTTPStatusError``.
        max_attempts: Total attempts before giving up.
        base_delay: Initial delay in seconds between retries.
        max_delay: Cap on delay between retries.

    Returns:
        The return value of ``fn`` on success.

    Raises:
        httpx.HTTPStatusError: If all retries are exhausted or the error
            is not transient.
    """
    last_exc: httpx.HTTPStatusError | None = None

    for attempt in range(max_attempts):
        try:
            return fn()
        except httpx.HTTPStatusError as exc:
            if exc.response.status_code not in _TRANSIENT_STATUS_CODES:
                raise
            last_exc = exc
            if attempt < max_attempts - 1:
                delay = min(base_delay * (2**attempt), max_delay)
                logger.warning(
                    "Transient %d on attempt %d/%d, retrying in %.1fs",
                    exc.response.status_code,
                    attempt + 1,
                    max_attempts,
                    delay,
                )
                time.sleep(delay)

    assert last_exc is not None  # noqa: S101
    raise last_exc
