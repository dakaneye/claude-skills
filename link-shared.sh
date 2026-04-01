#!/usr/bin/env bash
set -Eeuo pipefail

# Link shared assets from claude-skills into ~/.claude
# Run after cloning both dakaclaude (→ ~/.claude) and claude-skills
#
# Source of truth: claude-skills owns shared review assets
# Private-only files in ~/.claude are left untouched

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$SCRIPT_DIR/skills/review-code"
TARGET="$HOME/.claude"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { printf '%b\n' "${GREEN}[INFO]${NC} $*"; }
log_warn()  { printf '%b\n' "${YELLOW}[WARN]${NC} $*"; }
log_error() { printf '%b\n' "${RED}[ERROR]${NC} $*" >&2; }

# Validate both repos exist
if [[ ! -d "$TARGET" ]]; then
    log_error "~/.claude not found — clone dakaclaude first"
    exit 1
fi
if [[ ! -f "$SKILL_DIR/SKILL.md" ]]; then
    log_error "claude-skills/skills/review-code not found at $SKILL_DIR"
    exit 1
fi

link_file() {
    local src="$1" dst="$2"
    if [[ -L "$dst" ]]; then
        local current
        current="$(readlink "$dst")"
        if [[ "$current" = "$src" ]]; then
            return 0  # already correct
        fi
        rm "$dst"
    elif [[ -f "$dst" ]]; then
        log_warn "Replacing real file: $dst"
        rm "$dst"
    fi
    ln -s "$src" "$dst"
    log_info "Linked $(basename "$dst")"
}

link_dir() {
    local src="$1" dst="$2"
    if [[ -L "$dst" ]]; then
        local current
        current="$(readlink "$dst")"
        if [[ "$current" = "$src" ]]; then
            return 0
        fi
        rm "$dst"
    elif [[ -d "$dst" ]]; then
        log_warn "Replacing real directory: $dst"
        rm -rf "$dst"
    fi
    ln -s "$src" "$dst"
    log_info "Linked $(basename "$dst")/"
}

# --- Rules (per-file: .claude has private rust.md) ---
log_info "=== Rules ==="
for rule in bash go java nodejs python rust terraform; do
    src="$SKILL_DIR/rules/${rule}.md"
    [[ -f "$src" ]] || continue
    link_file "$src" "$TARGET/rules/${rule}.md"
done

# --- Concepts: language-standards (per-language dir symlinks) ---
log_info "=== Concepts: language-standards ==="
mkdir -p "$TARGET/concepts/language-standards"
for lang in bash go java nodejs python rust terraform; do
    src="$SKILL_DIR/concepts/language-standards/$lang"
    [[ -d "$src" ]] || continue
    link_dir "$src" "$TARGET/concepts/language-standards/$lang"
done
# code-review.md concept
if [[ -f "$SKILL_DIR/concepts/code-review.md" ]]; then
    link_file "$SKILL_DIR/concepts/code-review.md" "$TARGET/concepts/code-review.md"
fi

# --- Patterns (directory-level: 100% shared) ---
log_info "=== Patterns ==="
link_dir "$SKILL_DIR/patterns" "$TARGET/patterns"

# --- Agents (per-file: .claude has 40+ private agents) ---
log_info "=== Agents ==="
mkdir -p "$TARGET/agents"
for agent in "$SKILL_DIR"/agents/*.md; do
    [[ -f "$agent" ]] || continue
    name="$(basename "$agent")"
    link_file "$agent" "$TARGET/agents/$name"
done

# --- Skill: review-code (directory-level) ---
log_info "=== Skills ==="
link_dir "$SKILL_DIR" "$TARGET/skills/review-code"

# --- Summary ---
echo ""
log_info "Done. Shared assets symlinked from claude-skills → ~/.claude"
log_info "Private-only files in ~/.claude are untouched."
echo ""
echo "Verify with: ls -la ~/.claude/rules/ ~/.claude/agents/ ~/.claude/patterns"
