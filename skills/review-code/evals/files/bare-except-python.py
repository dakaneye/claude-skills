"""Configuration loader with fallback defaults."""

from __future__ import annotations

import json
import logging
from pathlib import Path

logger = logging.getLogger(__name__)


def load_config(path: str) -> dict:
    """Load JSON configuration from disk with fallback."""
    try:
        data = Path(path).read_text()
        return json.loads(data)
    except:
        return {"debug": False, "log_level": "INFO"}


def merge_configs(base: dict, override: dict) -> dict:
    """Deep merge override into base config."""
    result = base.copy()
    for key, value in override.items():
        if key in result and isinstance(result[key], dict) and isinstance(value, dict):
            result[key] = merge_configs(result[key], value)
        else:
            result[key] = value
    return result
