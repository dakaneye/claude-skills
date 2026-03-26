#!/usr/bin/env bash

# review-code-skill installer
# Installs the review-code skill and its dependencies into ~/.claude/

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${HOME}/.claude"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Backup existing files
backup_if_exists() {
    local path="$1"
    if [[ -e "$path" ]]; then
        local backup="${path}.backup.$(date +%Y%m%d%H%M%S)"
        log_warn "Backing up existing $path to $backup"
        mv "$path" "$backup"
    fi
}

# Create directory structure
create_dirs() {
    local dirs=(
        "$TARGET_DIR/skills/review-code"
        "$TARGET_DIR/scripts"
        "$TARGET_DIR/rules"
        "$TARGET_DIR/agents"
        "$TARGET_DIR/concepts/language-standards/bash"
        "$TARGET_DIR/concepts/language-standards/go"
        "$TARGET_DIR/concepts/language-standards/java"
        "$TARGET_DIR/concepts/language-standards/nodejs"
        "$TARGET_DIR/concepts/language-standards/python"
        "$TARGET_DIR/concepts/language-standards/terraform"
        "$TARGET_DIR/patterns/anti-patterns"
        "$TARGET_DIR/patterns/architecture"
        "$TARGET_DIR/patterns/ddd"
        "$TARGET_DIR/patterns/distributed"
        "$TARGET_DIR/patterns/enterprise"
        "$TARGET_DIR/patterns/gof/behavioral"
        "$TARGET_DIR/patterns/gof/creational"
        "$TARGET_DIR/patterns/gof/structural"
        "$TARGET_DIR/patterns/reliability"
    )

    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
    done
    log_info "Created directory structure"
}

# Copy files with verification
copy_files() {
    log_info "Installing skill files..."

    # Main skill file
    cp "$SCRIPT_DIR/skills/review-code/SKILL.md" "$TARGET_DIR/skills/review-code/"

    # Scripts (make executable)
    for script in get-pr-context.sh get-failing-checks.sh gh-issue.sh pr-context-lib.sh; do
        if [[ -f "$SCRIPT_DIR/scripts/$script" ]]; then
            cp "$SCRIPT_DIR/scripts/$script" "$TARGET_DIR/scripts/"
            chmod +x "$TARGET_DIR/scripts/$script"
        fi
    done

    # Rules
    for rule in bash.md go.md java.md nodejs.md python.md terraform.md; do
        if [[ -f "$SCRIPT_DIR/rules/$rule" ]]; then
            cp "$SCRIPT_DIR/rules/$rule" "$TARGET_DIR/rules/"
        fi
    done

    # Concepts
    cp "$SCRIPT_DIR/concepts/code-review.md" "$TARGET_DIR/concepts/"

    # Language standards
    for lang in bash go java nodejs python terraform; do
        if [[ -d "$SCRIPT_DIR/concepts/language-standards/$lang" ]]; then
            cp "$SCRIPT_DIR/concepts/language-standards/$lang"/*.md "$TARGET_DIR/concepts/language-standards/$lang/" 2>/dev/null || true
        fi
    done

    # Patterns
    cp "$SCRIPT_DIR/patterns/detection-signals.md" "$TARGET_DIR/patterns/"
    cp "$SCRIPT_DIR/patterns/INDEX.md" "$TARGET_DIR/patterns/" 2>/dev/null || true

    # Pattern subdirectories
    for subdir in anti-patterns architecture ddd distributed enterprise reliability; do
        if [[ -d "$SCRIPT_DIR/patterns/$subdir" ]]; then
            cp "$SCRIPT_DIR/patterns/$subdir"/*.md "$TARGET_DIR/patterns/$subdir/" 2>/dev/null || true
        fi
    done

    # GoF patterns (nested structure)
    for gof_subdir in behavioral creational structural; do
        if [[ -d "$SCRIPT_DIR/patterns/gof/$gof_subdir" ]]; then
            cp "$SCRIPT_DIR/patterns/gof/$gof_subdir"/*.md "$TARGET_DIR/patterns/gof/$gof_subdir/" 2>/dev/null || true
        fi
    done

    # Agents (custom subagent definitions)
    if [[ -d "$SCRIPT_DIR/agents" ]]; then
        cp "$SCRIPT_DIR/agents"/*.md "$TARGET_DIR/agents/" 2>/dev/null || true
        log_info "Installed $(ls "$SCRIPT_DIR/agents"/*.md 2>/dev/null | wc -l | tr -d ' ') agent definitions"
    fi

    log_info "Files installed successfully"
}

# Verify installation
verify_install() {
    log_info "Verifying installation..."

    local required_files=(
        "$TARGET_DIR/skills/review-code/SKILL.md"
        "$TARGET_DIR/scripts/get-pr-context.sh"
        "$TARGET_DIR/concepts/code-review.md"
        "$TARGET_DIR/patterns/detection-signals.md"
        "$TARGET_DIR/agents/golang-pro.md"
        "$TARGET_DIR/agents/truth-verifier.md"
    )

    local missing=0
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "Missing: $file"
            ((missing++))
        fi
    done

    if [[ $missing -eq 0 ]]; then
        log_info "All required files present"
        return 0
    else
        log_error "$missing required files missing"
        return 1
    fi
}

# Print usage instructions
print_usage() {
    cat <<'EOF'

=== Installation Complete ===

To use the review-code skill in Claude Code:

1. Add the skill to your CLAUDE.md manifest (if using PRPM):

   <skill>
   <name>review-code</name>
   <description>Comprehensive code review with language-specific expertise</description>
   <path>skills/review-code/SKILL.md</path>
   </skill>

2. Or invoke directly:
   /review-code [PR-URL|file|directory]

3. The skill uses these helper scripts:
   ~/.claude/scripts/get-pr-context.sh [PR_NUMBER]
   ~/.claude/scripts/get-failing-checks.sh [PR_NUMBER]
   ~/.claude/scripts/gh-issue.sh [ISSUE_NUMBER]

4. Language rules are in ~/.claude/rules/
5. Pattern references are in ~/.claude/patterns/
6. Detailed language standards are in ~/.claude/concepts/language-standards/

EOF
}

# Main
main() {
    echo "=== review-code Skill Installer ==="
    echo ""

    # Check if target exists
    if [[ -d "$TARGET_DIR" ]]; then
        log_info "Installing into existing $TARGET_DIR"
    else
        log_info "Creating $TARGET_DIR"
        mkdir -p "$TARGET_DIR"
    fi

    create_dirs
    copy_files

    if verify_install; then
        print_usage
    else
        log_error "Installation may be incomplete. Please check the errors above."
        exit 1
    fi
}

main "$@"
