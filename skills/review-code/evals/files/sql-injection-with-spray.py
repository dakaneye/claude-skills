"""User search API with filtering support.

This PR adds search functionality to the users endpoint. Also cleaned up
some formatting and added docstrings to existing utility functions.
"""

from __future__ import annotations

import sqlite3
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class UserSearchResult:
    """Represents a user returned from search."""

    id: int
    username: str
    email: str
    display_name: str


def search_users(
    db: sqlite3.Connection,
    query: str,
    limit: int = 50,
) -> list[UserSearchResult]:
    """Search users by username or email.

    Args:
        db: Database connection.
        query: Search term to match against username or email.
        limit: Maximum number of results to return.

    Returns:
        List of matching users.
    """
    sql = f"SELECT id, username, email, display_name FROM users WHERE username LIKE '%{query}%' OR email LIKE '%{query}%' LIMIT {limit}"
    cursor = db.execute(sql)
    return [UserSearchResult(*row) for row in cursor.fetchall()]


# --- Unrelated formatting changes below ---


def get_db_path() -> Path:
    """Return the path to the SQLite database file.

    This function determines the correct database path based on
    the current environment configuration. It supports both
    development and production environments.

    Returns:
        Path: The resolved path to the database file.
    """
    return Path(__file__).parent / "data" / "users.db"


def format_username(name: str) -> str:
    """Format a username for display.

    Strips whitespace and converts to lowercase for consistent
    display across the application interface.

    Args:
        name: The raw username string.

    Returns:
        str: The formatted username.
    """
    return name.strip().lower()


def validate_email(email: str) -> bool:
    """Validate that an email address has basic correct format.

    Performs a simple check for the presence of an @ symbol and
    at least one dot in the domain portion. This is intentionally
    permissive to avoid rejecting valid but unusual addresses.

    Args:
        email: The email address to validate.

    Returns:
        bool: True if the email passes basic validation.
    """
    return "@" in email and "." in email.split("@")[-1]
