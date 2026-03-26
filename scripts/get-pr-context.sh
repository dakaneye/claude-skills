#!/bin/bash

# Get PR Context Script
# Gathers comprehensive PR information from GitHub and saves to structured directory
# Supports subcommands for resolution tracking and status checking

set -euo pipefail

# Source the PR context library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/pr-context-lib.sh"

# Global state
PR_NUM=""
REPO_OVERRIDE=""
SUBCOMMAND=""
FORCE_REFRESH=false
THREAD_ID=""
COMMIT_SHA=""

# Usage info
usage() {
    cat <<EOF
Usage: $(basename "$0") [SUBCOMMAND] [OPTIONS] [PR_NUMBER]

Gathers comprehensive PR information from GitHub and saves to structured directory.

SUBCOMMANDS:
  (default)             Fetch/refresh PR context
  mark-addressed ID     Mark a review thread as locally addressed
  pending               List pending action items
  --help, -h            Display this help message

OPTIONS:
  -r, --repo REPO       Override repository (format: owner/repo)
  --refresh             Force full refresh even if data exists
  --commit SHA          Commit SHA that addresses the thread (with mark-addressed)

EXAMPLES:
  # Fetch PR context for current branch
  $(basename "$0")

  # Fetch context for specific PR
  $(basename "$0") 123

  # Force refresh
  $(basename "$0") 123 --refresh

  # Mark thread as addressed
  $(basename "$0") mark-addressed PRRT_abc123 --commit abc1234

  # List pending items
  $(basename "$0") pending 123

OUTPUT:
  Writes to: ~/.claude/prs/<owner>-<repo>/<pr-number>/
  Also outputs summary to terminal

EOF
    exit 0
}

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            mark-addressed)
                SUBCOMMAND="mark-addressed"
                shift
                if [[ -n "${1:-}" && ! "$1" =~ ^- ]]; then
                    THREAD_ID="$1"
                    shift
                fi
                ;;
            pending)
                SUBCOMMAND="pending"
                shift
                ;;
            -r|--repo)
                if [[ -z "${2:-}" ]]; then
                    echo -e "${RED}Error: Option $1 requires an argument${NC}" >&2
                    exit 1
                fi
                REPO_OVERRIDE="$2"
                shift 2
                ;;
            --refresh)
                FORCE_REFRESH=true
                shift
                ;;
            --commit)
                if [[ -z "${2:-}" ]]; then
                    echo -e "${RED}Error: Option $1 requires an argument${NC}" >&2
                    exit 1
                fi
                COMMIT_SHA="$2"
                shift 2
                ;;
            -h|--help)
                usage
                ;;
            -*)
                echo -e "${RED}Error: Unknown option: $1${NC}" >&2
                exit 1
                ;;
            *)
                # Could be PR number or URL
                if [[ -z "$PR_NUM" ]]; then
                    PR_NUM="$1"
                fi
                shift
                ;;
        esac
    done

    # Parse PR URL if provided
    if [[ -n "$PR_NUM" && "$PR_NUM" =~ ^https://github.com/([^/]+)/([^/]+)/pull/([0-9]+)(/.*)?$ ]]; then
        REPO_OVERRIDE="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
        PR_NUM="${BASH_REMATCH[3]}"
        echo -e "${BLUE}Detected PR URL: $REPO_OVERRIDE #$PR_NUM${NC}"
    fi
}

# Get repo info from override or git
get_repo_info() {
    if [[ -n "$REPO_OVERRIDE" ]]; then
        if [[ "$REPO_OVERRIDE" =~ ^([^/]+)/([^/]+)$ ]]; then
            OWNER="${BASH_REMATCH[1]}"
            REPO="${BASH_REMATCH[2]}"
            return 0
        else
            echo -e "${RED}Error: Invalid repo format: $REPO_OVERRIDE${NC}" >&2
            exit 1
        fi
    fi
    parse_repo_from_git
}

# Determine PR number from branch if not provided
determine_pr() {
    if [[ -z "$PR_NUM" ]]; then
        local branch
        branch=$(git branch --show-current 2>/dev/null || echo "")
        echo -e "${YELLOW}Current branch: $branch${NC}"

        PR_NUM=$(gh pr status --json currentBranch -q '.currentBranch.number' 2>/dev/null || echo "")

        if [[ -z "$PR_NUM" ]]; then
            echo -e "${RED}No PR found for current branch${NC}"
            echo "Usage: $0 [PR_NUMBER]"
            exit 1
        fi
    fi
    echo -e "${GREEN}PR #$PR_NUM from $OWNER/$REPO${NC}"
}

# Fetch and save PR data to directory structure
fetch_pr_context() {
    local pr_dir
    pr_dir=$(get_pr_dir_path "$OWNER" "$REPO" "$PR_NUM")

    # Create directory structure
    create_pr_directory "$OWNER" "$REPO" "$PR_NUM"

    echo -e "${BLUE}Fetching PR #$PR_NUM...${NC}"

    # Fetch PR metadata
    local pr_json
    pr_json=$(gh pr view "$PR_NUM" --repo "$OWNER/$REPO" \
        --json number,title,state,author,body,url,headRefName,baseRefName,mergeable,isDraft,labels,milestone,assignees,createdAt,updatedAt,additions,deletions,changedFiles,files)

    # Check if we need to refresh
    local pr_updated_at
    pr_updated_at=$(echo "$pr_json" | jq -r '.updatedAt // ""')

    if [[ "$FORCE_REFRESH" != "true" ]] && ! is_pr_stale "$OWNER" "$REPO" "$PR_NUM" "$pr_updated_at"; then
        echo -e "${GREEN}Using cached data (PR not modified since last fetch)${NC}"
        echo -e "${BLUE}Use --refresh to force update${NC}"
        # Still generate overview and show it
        generate_overview "$OWNER" "$REPO" "$PR_NUM"
        cat "$pr_dir/overview.md"
        return 0
    fi

    # Write core files
    write_metadata "$OWNER" "$REPO" "$PR_NUM" "$pr_json"
    local body
    body=$(echo "$pr_json" | jq -r '.body // ""')
    write_description "$OWNER" "$REPO" "$PR_NUM" "$body"
    local files_json
    files_json=$(echo "$pr_json" | jq '.files')
    write_files_json "$OWNER" "$REPO" "$PR_NUM" "$files_json"

    # Fetch and write diff
    echo -e "${BLUE}Fetching diff...${NC}"
    local diff
    diff=$(gh pr diff "$PR_NUM" --repo "$OWNER/$REPO" 2>/dev/null || echo "")
    write_diff "$OWNER" "$REPO" "$PR_NUM" "$diff"

    # Fetch reviews and threads via GraphQL
    echo -e "${BLUE}Fetching reviews and threads...${NC}"
    local reviews_data
    reviews_data=$(fetch_reviews_and_threads "$OWNER" "$REPO" "$PR_NUM")

    write_review_files "$OWNER" "$REPO" "$PR_NUM" "$reviews_data"
    write_reviews_index "$OWNER" "$REPO" "$PR_NUM" "$reviews_data"
    write_threads_index "$OWNER" "$REPO" "$PR_NUM" "$reviews_data"
    write_thread_files "$OWNER" "$REPO" "$PR_NUM" "$reviews_data"
    write_discussion_comments "$OWNER" "$REPO" "$PR_NUM" "$reviews_data"

    # Fetch CI status
    echo -e "${BLUE}Fetching CI status...${NC}"
    local head_sha
    head_sha=$(echo "$pr_json" | jq -r '.headRefOid // ""')
    if [[ -z "$head_sha" ]]; then
        head_sha=$(gh pr view "$PR_NUM" --repo "$OWNER/$REPO" --json headRefOid -q '.headRefOid' 2>/dev/null || echo "")
    fi
    if [[ -n "$head_sha" ]]; then
        local runs
        runs=$(gh api "repos/$OWNER/$REPO/actions/runs?head_sha=$head_sha&per_page=100" 2>/dev/null || echo '{"workflow_runs":[]}')
        write_ci_index "$OWNER" "$REPO" "$PR_NUM" "$runs"
    fi

    # Detect and copy planning docs
    detect_and_copy_planning_docs "$OWNER" "$REPO" "$PR_NUM" "$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"

    # Generate overview
    generate_overview "$OWNER" "$REPO" "$PR_NUM"

    # Mark as complete
    write_status "$OWNER" "$REPO" "$PR_NUM" "complete"

    echo ""
    echo -e "${GREEN}✓ Context saved to: $pr_dir${NC}"
    echo ""

    # Output overview to terminal
    cat "$pr_dir/overview.md"

    # Also show terminal-friendly summary
    echo ""
    section "TERMINAL OUTPUT"
    output_terminal_summary
}

# Output terminal-friendly summary (preserves existing behavior)
output_terminal_summary() {
    local pr_dir
    pr_dir=$(get_pr_dir_path "$OWNER" "$REPO" "$PR_NUM")

    # PR Info
    if [[ -f "$pr_dir/metadata.json" ]]; then
        local title state author additions deletions files
        title=$(jq -r '.pr.title // "Unknown"' "$pr_dir/metadata.json")
        state=$(jq -r '.pr.state // "Unknown"' "$pr_dir/metadata.json")
        author=$(jq -r '.pr.author // "Unknown"' "$pr_dir/metadata.json")
        additions=$(jq -r '.stats.additions // 0' "$pr_dir/metadata.json")
        deletions=$(jq -r '.stats.deletions // 0' "$pr_dir/metadata.json")
        files=$(jq -r '.stats.changedFiles // 0' "$pr_dir/metadata.json")

        echo -e "PR #$PR_NUM: $title"
        echo -e "State: $state | Author: @$author"
        echo -e "Stats: +$additions -$deletions across $files files"
        echo ""
    fi

    # Review summary
    if [[ -f "$pr_dir/reviews/index.json" ]]; then
        local approved changes_req commented
        approved=$(jq '.summary.approved // 0' "$pr_dir/reviews/index.json")
        changes_req=$(jq '.summary.changesRequested // 0' "$pr_dir/reviews/index.json")
        commented=$(jq '.summary.commented // 0' "$pr_dir/reviews/index.json")
        echo "Reviews: $approved approved, $changes_req changes requested, $commented commented"
    fi

    # Thread summary
    if [[ -f "$pr_dir/threads/index.json" ]]; then
        local total pending resolved
        total=$(jq '.summary.total // 0' "$pr_dir/threads/index.json")
        pending=$(jq '.summary.pending // 0' "$pr_dir/threads/index.json")
        resolved=$(jq '.summary.resolved // 0' "$pr_dir/threads/index.json")
        echo "Threads: $total total, $pending pending, $resolved resolved"
    fi

    # CI summary
    if [[ -f "$pr_dir/ci/index.json" ]]; then
        local success failure in_progress
        success=$(jq '.summary.success // 0' "$pr_dir/ci/index.json")
        failure=$(jq '.summary.failure // 0' "$pr_dir/ci/index.json")
        in_progress=$(jq '.summary.pending // 0' "$pr_dir/ci/index.json")
        echo "CI: $success passing, $failure failing, $in_progress pending"
    fi

    echo ""
    echo -e "${BLUE}Full context: $pr_dir${NC}"
}

# Handle mark-addressed subcommand
handle_mark_addressed() {
    if [[ -z "$THREAD_ID" ]]; then
        echo -e "${RED}Error: Thread ID required${NC}"
        echo "Usage: $0 mark-addressed THREAD_ID [--commit SHA]"
        exit 1
    fi

    get_repo_info
    determine_pr

    mark_thread_addressed "$OWNER" "$REPO" "$PR_NUM" "$THREAD_ID" "$COMMIT_SHA"
}

# Handle pending subcommand
handle_pending() {
    get_repo_info
    determine_pr

    get_pending_items "$OWNER" "$REPO" "$PR_NUM"
}

# Main execution
main() {
    # Check for gh CLI
    if ! command -v gh &> /dev/null; then
        echo -e "${RED}Error: GitHub CLI (gh) is not installed${NC}"
        echo "Install it from: https://cli.github.com/"
        exit 1
    fi

    # Check gh auth status
    if ! gh auth status &> /dev/null; then
        echo -e "${RED}Error: Not authenticated with GitHub${NC}"
        echo "Run: gh auth login"
        exit 1
    fi

    parse_args "$@"

    case "$SUBCOMMAND" in
        mark-addressed)
            handle_mark_addressed
            ;;
        pending)
            handle_pending
            ;;
        *)
            get_repo_info
            determine_pr
            fetch_pr_context
            ;;
    esac
}

main "$@"
