#!/usr/bin/env python3
"""Lint skills against skill framework conventions.

Checks:
- Version field present in prpm.json
- Description with trigger phrases in SKILL.md
- Line count within bounds
- Structure classification (procedural vs framework)

Adapted from dakaclaude skill-linter.py for this repo's layout.
"""

import json
import re
import sys
from pathlib import Path


LINE_LIMIT = 450
REPO_ROOT = Path(__file__).resolve().parent.parent


def find_skills() -> list[Path]:
    """Find all SKILL.md files under skills/."""
    skills_dir = REPO_ROOT / "skills"
    if not skills_dir.exists():
        return []
    return sorted(skills_dir.rglob("SKILL.md"))


def lint_skill(skill_md: Path) -> dict:
    content = skill_md.read_text()
    lines = content.splitlines()
    line_count = len(lines)

    # Derive name from parent directory
    name = skill_md.parent.name

    # Check version in prpm.json (PRPM forbids version in SKILL.md frontmatter)
    prpm_json = skill_md.parent / "prpm.json"
    has_version = False
    if prpm_json.exists():
        try:
            pkg = json.loads(prpm_json.read_text())
            has_version = bool(pkg.get("version"))
        except json.JSONDecodeError:
            pass

    # Check description with trigger language
    has_triggers = bool(re.search(
        r"Use (?:PROACTIVELY |this skill )?(?:when|after|for|to)"
        r"|activates when"
        r"|Trigger on"
        r"|Invoke proactively",
        content, re.IGNORECASE,
    ))

    # Line count check
    over_limit = line_count > LINE_LIMIT

    # Structure classification
    step_count = len(re.findall(r"(?:Step \d|Phase \d|### \d)", content))
    framework_count = len(re.findall(
        r"(?:Framework|Principle|Dimension|Scorecard|Matrix|Rubric)",
        content, re.IGNORECASE,
    ))

    if step_count > framework_count and step_count > 3:
        structure = "procedural"
    elif framework_count > step_count:
        structure = "framework"
    else:
        structure = "mixed"

    # Check evals exist
    evals_dir = skill_md.parent / "evals"
    has_reasoning_evals = (evals_dir / "evals.json").exists()
    has_trigger_evals = (evals_dir / "trigger-evals.json").exists()

    issues = []
    if not has_version:
        issues.append("missing version field")
    if not has_triggers:
        issues.append("no trigger phrases in description")
    if over_limit:
        issues.append(f"over line limit ({line_count}/{LINE_LIMIT})")
    if not has_reasoning_evals:
        issues.append("missing evals/evals.json")
    if not has_trigger_evals:
        issues.append("missing evals/trigger-evals.json")

    return {
        "name": name,
        "path": str(skill_md.relative_to(REPO_ROOT)),
        "line_count": line_count,
        "has_version": has_version,
        "has_triggers": has_triggers,
        "over_limit": over_limit,
        "structure": structure,
        "has_reasoning_evals": has_reasoning_evals,
        "has_trigger_evals": has_trigger_evals,
        "issues": issues,
        "pass": len(issues) == 0,
    }


def main():
    skills = find_skills()
    if not skills:
        print("No SKILL.md files found under skills/", file=sys.stderr)
        sys.exit(1)

    results = [lint_skill(s) for s in skills]

    total = len(results)
    passing = sum(1 for r in results if r["pass"])
    failing = total - passing

    report = {
        "summary": {
            "total": total,
            "passing": passing,
            "failing": failing,
            "line_limit": LINE_LIMIT,
        },
        "skills": results,
    }

    print(json.dumps(report, indent=2))

    if failing > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
