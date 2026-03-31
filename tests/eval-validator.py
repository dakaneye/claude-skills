#!/usr/bin/env python3
"""Validate skill eval files for correct structure.

Checks:
- evals.json: has skill_name, evals array, each eval has id/prompt/assertions
- trigger-evals.json: array of objects with query and should_trigger fields

Runs as part of CI to catch malformed evals before they ship.
"""

import json
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent


def validate_evals(evals_file: Path) -> list[str]:
    """Validate reasoning evals structure. Returns list of errors."""
    errors = []

    try:
        data = json.loads(evals_file.read_text())
    except json.JSONDecodeError as e:
        return [f"invalid JSON: {e}"]

    if not isinstance(data, dict):
        return ["evals.json must be a JSON object"]

    if "skill_name" not in data:
        errors.append("missing 'skill_name' field")

    evals = data.get("evals", [])
    if not isinstance(evals, list):
        errors.append("'evals' must be an array")
        return errors

    if len(evals) == 0:
        errors.append("'evals' array is empty")

    for i, eval_case in enumerate(evals):
        prefix = f"evals[{i}]"

        if "id" not in eval_case:
            errors.append(f"{prefix}: missing 'id'")

        if "prompt" not in eval_case:
            errors.append(f"{prefix}: missing 'prompt'")
        elif not eval_case["prompt"].strip():
            errors.append(f"{prefix}: 'prompt' is empty")

        assertions = eval_case.get("assertions", [])
        if not isinstance(assertions, list):
            errors.append(f"{prefix}: 'assertions' must be an array")
        elif len(assertions) == 0:
            errors.append(f"{prefix}: no assertions defined")
        else:
            for j, assertion in enumerate(assertions):
                a_prefix = f"{prefix}.assertions[{j}]"
                if "text" not in assertion:
                    errors.append(f"{a_prefix}: missing 'text'")
                if "keywords" in assertion and not isinstance(assertion["keywords"], list):
                    errors.append(f"{a_prefix}: 'keywords' must be an array")

    return errors


def validate_trigger_evals(trigger_file: Path) -> list[str]:
    """Validate trigger evals structure. Returns list of errors."""
    errors = []

    try:
        data = json.loads(trigger_file.read_text())
    except json.JSONDecodeError as e:
        return [f"invalid JSON: {e}"]

    if not isinstance(data, list):
        return ["trigger-evals.json must be a JSON array"]

    if len(data) == 0:
        errors.append("trigger evals array is empty")

    has_should = False
    has_should_not = False

    for i, entry in enumerate(data):
        prefix = f"trigger-evals[{i}]"

        if "query" not in entry:
            errors.append(f"{prefix}: missing 'query'")
        elif not entry["query"].strip():
            errors.append(f"{prefix}: 'query' is empty")

        if "should_trigger" not in entry:
            errors.append(f"{prefix}: missing 'should_trigger'")
        elif not isinstance(entry["should_trigger"], bool):
            errors.append(f"{prefix}: 'should_trigger' must be boolean")
        else:
            if entry["should_trigger"]:
                has_should = True
            else:
                has_should_not = True

    if not has_should:
        errors.append("no positive trigger cases (should_trigger: true)")
    if not has_should_not:
        errors.append("no negative trigger cases (should_trigger: false)")

    return errors


def main():
    skills_dir = REPO_ROOT / "skills"
    if not skills_dir.exists():
        print("No skills/ directory found", file=sys.stderr)
        sys.exit(1)

    eval_dirs = sorted(skills_dir.rglob("evals"))
    if not eval_dirs:
        print("No evals/ directories found under skills/", file=sys.stderr)
        sys.exit(1)

    total_errors = 0

    for evals_dir in eval_dirs:
        skill_name = evals_dir.parent.name
        print(f"Validating evals for: {skill_name}")

        evals_file = evals_dir / "evals.json"
        trigger_file = evals_dir / "trigger-evals.json"

        if evals_file.exists():
            errors = validate_evals(evals_file)
            if errors:
                for e in errors:
                    print(f"  FAIL evals.json: {e}")
                total_errors += len(errors)
            else:
                data = json.loads(evals_file.read_text())
                count = len(data.get("evals", []))
                print(f"  PASS evals.json ({count} evals)")
        else:
            print(f"  SKIP evals.json (not found)")

        if trigger_file.exists():
            errors = validate_trigger_evals(trigger_file)
            if errors:
                for e in errors:
                    print(f"  FAIL trigger-evals.json: {e}")
                total_errors += len(errors)
            else:
                data = json.loads(trigger_file.read_text())
                print(f"  PASS trigger-evals.json ({len(data)} triggers)")
        else:
            print(f"  SKIP trigger-evals.json (not found)")

    if total_errors > 0:
        print(f"\n{total_errors} error(s) found")
        sys.exit(1)
    else:
        print("\nAll evals valid")


if __name__ == "__main__":
    main()
