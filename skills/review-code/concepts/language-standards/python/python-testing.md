# Python Testing with pytest

> Fixtures, parametrize, and mocking best practices.

## Fixture Patterns

```python
# WRONG: Setup in each test
def test_user_creation():
    db = create_test_database()
    user_service = UserService(db)
    user = user_service.create(name="test")
    assert user.name == "test"
    db.cleanup()

def test_user_deletion():
    db = create_test_database()  # Duplicate setup
    user_service = UserService(db)
    # ...

# RIGHT: Fixtures for shared setup
import pytest

@pytest.fixture
def db():
    database = create_test_database()
    yield database
    database.cleanup()

@pytest.fixture
def user_service(db):
    return UserService(db)

def test_user_creation(user_service):
    user = user_service.create(name="test")
    assert user.name == "test"

def test_user_deletion(user_service):
    # db fixture automatically provided
    pass

# WRONG: Fixture that's too broad
@pytest.fixture
def everything():
    return {
        "db": create_db(),
        "cache": create_cache(),
        "user_service": UserService(...),
        "order_service": OrderService(...),
    }

# RIGHT: Composable fixtures
@pytest.fixture
def db():
    return create_db()

@pytest.fixture
def cache():
    return create_cache()

@pytest.fixture
def user_service(db, cache):
    return UserService(db, cache)
```

## Parametrize for Test Cases

```python
# WRONG: Duplicate tests for variations
def test_validate_email_valid():
    assert validate_email("user@example.com") is True

def test_validate_email_no_at():
    assert validate_email("userexample.com") is False

def test_validate_email_no_domain():
    assert validate_email("user@") is False

# RIGHT: Parametrized tests
@pytest.mark.parametrize(
    "email,expected",
    [
        ("user@example.com", True),
        ("user.name+tag@example.co.uk", True),
        ("userexample.com", False),
        ("user@", False),
        ("@example.com", False),
        ("", False),
    ],
    ids=["valid", "valid_complex", "no_at", "no_domain", "no_local", "empty"],
)
def test_validate_email(email: str, expected: bool):
    assert validate_email(email) is expected

# WRONG: Testing implementation details
def test_user_service_calls_repository():
    repo = Mock()
    service = UserService(repo)
    service.get_user(123)
    repo.find_by_id.assert_called_once_with(123)  # Coupling to implementation

# RIGHT: Test behavior, not implementation
def test_user_service_returns_user():
    repo = Mock()
    repo.find_by_id.return_value = User(id=123, name="Alice")
    service = UserService(repo)

    user = service.get_user(123)

    assert user.name == "Alice"
```

## Mocking Best Practices

```python
# WRONG: Mocking everything
def test_process_order(mocker):
    mocker.patch("app.services.validate_order")
    mocker.patch("app.services.calculate_total")
    mocker.patch("app.services.apply_discount")
    mocker.patch("app.services.save_order")
    mocker.patch("app.services.send_notification")

    result = process_order(order)  # What are we even testing?

# RIGHT: Mock at boundaries, test the logic
def test_process_order(mocker):
    # Only mock external dependencies
    mock_db = mocker.patch("app.services.database")
    mock_email = mocker.patch("app.services.email_client")

    order = create_test_order(items=[Item(price=100, qty=2)])

    result = process_order(order)

    assert result.total == 200
    assert result.status == "confirmed"
    mock_email.send.assert_called_once()

# WRONG: Patching at the wrong location
# In app/services.py:
# from app.utils import validate

# In test:
mocker.patch("app.utils.validate")  # Wrong! Won't affect services.py

# RIGHT: Patch where it's used
mocker.patch("app.services.validate")  # Correct location
```

---

## Quick Reference

| Pattern | Problem | Fix |
|---------|---------|-----|
| Setup in each test | Duplication | Use fixtures |
| Huge "everything" fixture | Hard to understand | Composable fixtures |
| Multiple similar tests | Verbose | `@pytest.mark.parametrize` |
| Assert on mock calls | Tests implementation | Assert on behavior |
| Mock everything | Not testing anything | Mock only boundaries |
| Patch at definition site | Doesn't work | Patch where imported |
