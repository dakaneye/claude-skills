#!/usr/bin/env bash

# Skill installer for dakaneye/claude-skills
# Installs a skill into ~/.claude/skills/dakaneye-<skill-name>/
# Uses the same flat structure as PRPM for consistency
#
# Usage: ./install.sh <skill-name>
# Example: ./install.sh review-code

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

usage() {
    echo "Usage: $0 <skill-name>"
    echo ""
    echo "Available skills:"
    for skill_dir in "$SCRIPT_DIR"/skills/*/; do
        [[ -d "$skill_dir" ]] || continue
        local name
        name=$(basename "$skill_dir")
        echo "  - $name"
    done
    exit 1
}

if [[ $# -lt 1 ]]; then
    usage
fi

SKILL_NAME="$1"
SKILL_SRC="$SCRIPT_DIR/skills/$SKILL_NAME"
TARGET_DIR="${HOME}/.claude/skills/dakaneye-${SKILL_NAME}"

if [[ ! -d "$SKILL_SRC" ]]; then
    log_error "Skill not found: $SKILL_NAME"
    usage
fi

if [[ ! -f "$SKILL_SRC/SKILL.md" ]]; then
    log_error "No SKILL.md found in $SKILL_SRC"
    exit 1
fi

# Backup existing installation
if [[ -d "$TARGET_DIR" ]]; then
    backup="${TARGET_DIR}.backup.$(date +%Y%m%d%H%M%S)"
    log_warn "Backing up existing installation to $backup"
    mv "$TARGET_DIR" "$backup"
fi

# Copy all files to flat structure (matching PRPM behavior)
log_info "Installing $SKILL_NAME to $TARGET_DIR (flat structure)..."
mkdir -p "$TARGET_DIR"

# SKILL.md
cp "$SKILL_SRC/SKILL.md" "$TARGET_DIR/"

# Scripts (make executable)
for script in "$SKILL_SRC"/scripts/*.sh; do
    [[ -f "$script" ]] || continue
    cp "$script" "$TARGET_DIR/"
    chmod +x "$TARGET_DIR/$(basename "$script")"
done

# Flat markdown files from agents/, rules/
for dir in agents rules; do
    for file in "$SKILL_SRC/$dir"/*.md; do
        [[ -f "$file" ]] || continue
        cp "$file" "$TARGET_DIR/"
    done
done

# Concepts (flatten nested structure)
if [[ -d "$SKILL_SRC/concepts" ]]; then
    find "$SKILL_SRC/concepts" -name '*.md' -type f -exec cp {} "$TARGET_DIR/" \;
fi

# Patterns (flatten nested structure)
if [[ -d "$SKILL_SRC/patterns" ]]; then
    find "$SKILL_SRC/patterns" -name '*.md' -type f -exec cp {} "$TARGET_DIR/" \;
fi

# README and LICENSE from repo root
cp "$SCRIPT_DIR/README.md" "$TARGET_DIR/"
cp "$SCRIPT_DIR/LICENSE" "$TARGET_DIR/"

# Verify
file_count=$(find "$TARGET_DIR" -type f | wc -l | tr -d ' ')
log_info "Installed $file_count files"

if [[ -f "$TARGET_DIR/SKILL.md" ]]; then
    log_info "Installation complete: $TARGET_DIR"
else
    log_error "Installation may be incomplete — SKILL.md not found in target"
    exit 1
fi

echo ""
echo "=== Installed: dakaneye-${SKILL_NAME} ==="
echo "Location: $TARGET_DIR"
echo "Invoke:   /${SKILL_NAME}"
