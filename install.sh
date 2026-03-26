#!/usr/bin/env bash

# review-code skill installer
# Installs the review-code skill into ~/.claude/skills/dakaneye-review-code/
# Uses the same flat structure as PRPM for consistency

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${HOME}/.claude/skills/dakaneye-review-code"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Backup existing installation
backup_if_exists() {
    if [[ -d "$TARGET_DIR" ]]; then
        local backup="${TARGET_DIR}.backup.$(date +%Y%m%d%H%M%S)"
        log_warn "Backing up existing installation to $backup"
        mv "$TARGET_DIR" "$backup"
    fi
}

# Copy all files to flat structure (matching PRPM behavior)
copy_files() {
    log_info "Installing to $TARGET_DIR (flat structure)..."

    mkdir -p "$TARGET_DIR"

    # Main skill file
    cp "$SCRIPT_DIR/skills/review-code/SKILL.md" "$TARGET_DIR/"

    # Scripts (make executable)
    for script in "$SCRIPT_DIR"/scripts/*.sh; do
        [[ -f "$script" ]] || continue
        cp "$script" "$TARGET_DIR/"
        chmod +x "$TARGET_DIR/$(basename "$script")"
    done

    # Rules
    for rule in "$SCRIPT_DIR"/rules/*.md; do
        [[ -f "$rule" ]] || continue
        cp "$rule" "$TARGET_DIR/"
    done

    # Agents
    for agent in "$SCRIPT_DIR"/agents/*.md; do
        [[ -f "$agent" ]] || continue
        cp "$agent" "$TARGET_DIR/"
    done

    # Concepts (flatten)
    cp "$SCRIPT_DIR/concepts/code-review.md" "$TARGET_DIR/"
    for lang_dir in "$SCRIPT_DIR"/concepts/language-standards/*/; do
        [[ -d "$lang_dir" ]] || continue
        for file in "$lang_dir"*.md; do
            [[ -f "$file" ]] || continue
            cp "$file" "$TARGET_DIR/"
        done
    done

    # Patterns (flatten)
    cp "$SCRIPT_DIR/patterns/detection-signals.md" "$TARGET_DIR/"
    [[ -f "$SCRIPT_DIR/patterns/INDEX.md" ]] && cp "$SCRIPT_DIR/patterns/INDEX.md" "$TARGET_DIR/"

    for pattern_dir in "$SCRIPT_DIR"/patterns/*/; do
        [[ -d "$pattern_dir" ]] || continue
        # Handle nested GoF structure
        if [[ "$(basename "$pattern_dir")" == "gof" ]]; then
            for gof_subdir in "$pattern_dir"*/; do
                [[ -d "$gof_subdir" ]] || continue
                for file in "$gof_subdir"*.md; do
                    [[ -f "$file" ]] || continue
                    cp "$file" "$TARGET_DIR/"
                done
            done
        else
            for file in "$pattern_dir"*.md; do
                [[ -f "$file" ]] || continue
                cp "$file" "$TARGET_DIR/"
            done
        fi
    done

    # README and LICENSE
    cp "$SCRIPT_DIR/README.md" "$TARGET_DIR/"
    cp "$SCRIPT_DIR/LICENSE" "$TARGET_DIR/"

    log_info "Files installed successfully"
}

# Verify installation
verify_install() {
    log_info "Verifying installation..."

    local required_files=(
        "$TARGET_DIR/SKILL.md"
        "$TARGET_DIR/get-pr-context.sh"
        "$TARGET_DIR/code-review.md"
        "$TARGET_DIR/detection-signals.md"
        "$TARGET_DIR/golang-pro.md"
        "$TARGET_DIR/truth-verifier.md"
    )

    local missing=0
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "Missing: $file"
            ((missing++))
        fi
    done

    local file_count
    file_count=$(find "$TARGET_DIR" -type f | wc -l | tr -d ' ')
    log_info "Installed $file_count files"

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

The review-code skill is installed to ~/.claude/skills/dakaneye-review-code/

To use in Claude Code:

1. Invoke directly:
   /review-code [PR-URL|file|directory]

2. Helper scripts:
   ~/.claude/skills/dakaneye-review-code/get-pr-context.sh [PR_NUMBER]
   ~/.claude/skills/dakaneye-review-code/get-failing-checks.sh [PR_NUMBER]
   ~/.claude/skills/dakaneye-review-code/gh-issue.sh [ISSUE_NUMBER]

3. Add to your CLAUDE.md manifest:

   <skill>
   <name>review-code</name>
   <description>Comprehensive code review with language-specific expertise</description>
   <path>skills/review-code/SKILL.md</path>
   </skill>

EOF
}

# Main
main() {
    echo "=== review-code Skill Installer ==="
    echo ""

    backup_if_exists
    copy_files

    if verify_install; then
        print_usage
    else
        log_error "Installation may be incomplete. Please check the errors above."
        exit 1
    fi
}

main "$@"
