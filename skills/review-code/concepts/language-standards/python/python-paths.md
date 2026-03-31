# Python Path Handling

> pathlib vs os.path for modern, clean path manipulation.

## pathlib vs os.path

```python
# WRONG: os.path for path manipulation
import os

config_path = os.path.join(os.path.dirname(__file__), "config", "app.yaml")
if os.path.exists(config_path):
    with open(config_path) as f:
        content = f.read()

# RIGHT: pathlib for modern path handling
from pathlib import Path

config_path = Path(__file__).parent / "config" / "app.yaml"
if config_path.exists():
    content = config_path.read_text()

# WRONG: String manipulation for paths
base = "/var/log/app"
log_file = base + "/" + date + "/" + name + ".log"

# RIGHT: Path operators
base = Path("/var/log/app")
log_file = base / date / f"{name}.log"

# WRONG: os.path.splitext for suffix
filename = "data.tar.gz"
name, ext = os.path.splitext(filename)  # ext = ".gz", loses ".tar"

# RIGHT: pathlib suffix handling
path = Path("data.tar.gz")
suffixes = path.suffixes  # ['.tar', '.gz']
stem = path.stem  # "data.tar"
name = path.name  # "data.tar.gz"
```

## Common pathlib Patterns

```python
# Directory creation
path.mkdir(parents=True, exist_ok=True)  # mkdir -p

# File deletion
path.unlink(missing_ok=True)  # rm -f

# Recursive glob
list(path.glob("**/*.py"))

# Absolute path with symlink resolution
path.resolve()

# File I/O shortcuts
content = path.read_text()
path.write_text("data")
data = path.read_bytes()
path.write_bytes(b"data")

# Check file type
path.is_file()
path.is_dir()
path.is_symlink()

# Path parts
path.parent      # Parent directory
path.name        # Filename with extension
path.stem        # Filename without extension
path.suffix      # Extension
path.suffixes    # All extensions ['.tar', '.gz']
```

## Path Traversal Prevention

```python
# WRONG: Direct path join with user input
def read_document(filename: str) -> str:
    path = Path("/documents") / filename
    return path.read_text()  # filename="../../../etc/passwd" = bad

# RIGHT: Validate resolved path stays within allowed directory
def read_document(filename: str) -> str:
    base_dir = Path("/documents").resolve()
    target = (base_dir / filename).resolve()

    if not target.is_relative_to(base_dir):
        raise ValueError("Invalid path: escapes document directory")

    return target.read_text()
```

---

## Quick Reference

| os.path | pathlib | Notes |
|---------|---------|-------|
| `os.path.join(a, b)` | `Path(a) / b` | Use `/` operator |
| `os.path.dirname(p)` | `Path(p).parent` | Returns Path |
| `os.path.basename(p)` | `Path(p).name` | Filename only |
| `os.path.splitext(p)` | `Path(p).suffix` | Single extension |
| `os.path.exists(p)` | `Path(p).exists()` | Method call |
| `os.makedirs(p)` | `Path(p).mkdir(parents=True)` | Cleaner |
| `glob.glob("**/*.py")` | `Path(".").glob("**/*.py")` | Returns iterator |
| `open(p).read()` | `Path(p).read_text()` | One-liner |
