#!/bin/bash

# Get Failing CI Checks Script
# Fetches logs for failing CI checks, saves to PR context directory
# Handles fork workflows (PRs to upstream from fork)
# Supports both PR numbers and GitHub workflow run URLs

set -euo pipefail

# Source the PR context library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/pr-context-lib.sh"

# Note: Colors (RED, GREEN, YELLOW, BLUE, NC) are defined in pr-context-lib.sh

# Usage info
usage() {
    cat <<EOF
Usage: $(basename "$0") [PR_NUMBER | WORKFLOW_RUN_URL]

Fetch failing CI check logs for analysis.

Arguments:
  PR_NUMBER           GitHub PR number (e.g., 29304)
  WORKFLOW_RUN_URL    GitHub workflow run URL
                      (e.g., https://github.com/owner/repo/actions/runs/12345678)

If no argument is provided:
  - On a feature branch: finds the PR for the current branch
  - On main/master: checks the latest commit's workflow runs

Examples:
  $(basename "$0")                                               # Auto-detect PR or check main branch
  $(basename "$0") 29304                                         # Fetch logs for PR #29304
  $(basename "$0") https://github.com/owner/repo/actions/runs/12345678

EOF
    exit 0
}

INPUT="${1:-}"
PR_NUM=""
RUN_ID=""
OWNER=""
REPO=""
MODE="pr"  # pr, run, or branch

# Parse workflow run URL to extract owner, repo, and run_id
parse_workflow_url() {
    local url="$1"
    if [[ "$url" =~ ^https://github.com/([^/]+)/([^/]+)/actions/runs/([0-9]+)(/.*)?$ ]]; then
        OWNER="${BASH_REMATCH[1]}"
        REPO="${BASH_REMATCH[2]}"
        RUN_ID="${BASH_REMATCH[3]}"
        return 0
    else
        return 1
    fi
}

# Note: parse_pr_url is provided by pr-context-lib.sh

# Parse remote URL to get owner/repo
parse_remote_url() {
    local url="$1"
    if [[ "$url" =~ ^git@github.com:([^/]+)/([^/]+)(\.git)?$ ]]; then
        echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]%.git}"
    elif [[ "$url" =~ ^ssh://git@github.com/([^/]+)/([^/]+)(\.git)?$ ]]; then
        echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]%.git}"
    elif [[ "$url" =~ ^https://github.com/([^/]+)/([^/]+)(\.git)?$ ]]; then
        echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]%.git}"
    else
        echo ""
    fi
}

# Determine which repo to use (handles forks)
get_repo_info() {
    local origin_url upstream_url origin_repo upstream_repo

    origin_url=$(git remote get-url origin 2>/dev/null || echo "")
    upstream_url=$(git remote get-url upstream 2>/dev/null || echo "")

    origin_repo=$(parse_remote_url "$origin_url")
    upstream_repo=$(parse_remote_url "$upstream_url")

    # If we have an upstream remote, prefer it for PR lookups (fork workflow)
    if [ -n "$upstream_repo" ]; then
        OWNER="${upstream_repo%%/*}"
        REPO="${upstream_repo##*/}"
        echo -e "${BLUE}Detected fork workflow - checking upstream: $OWNER/$REPO${NC}"
    elif [ -n "$origin_repo" ]; then
        OWNER="${origin_repo%%/*}"
        REPO="${origin_repo##*/}"
    else
        echo -e "${RED}Error: Could not determine GitHub repository${NC}" >&2
        exit 1
    fi
}

# Parse input to determine mode (PR or workflow run)
parse_input() {
    if [ "$INPUT" = "-h" ] || [ "$INPUT" = "--help" ]; then
        usage
    fi

    if [ -z "$INPUT" ]; then
        # No input, will auto-detect PR
        MODE="pr"
        return
    fi

    # Check if input is a workflow run URL
    if parse_workflow_url "$INPUT"; then
        MODE="run"
        echo -e "${BLUE}Detected workflow run URL${NC}"
        echo -e "${BLUE}Repository: $OWNER/$REPO${NC}"
        echo -e "${BLUE}Run ID: $RUN_ID${NC}"
        return
    fi

    # Check if input is a PR URL
    if parse_pr_url "$INPUT"; then
        MODE="pr"
        echo -e "${BLUE}Detected PR URL${NC}"
        echo -e "${BLUE}Repository: $OWNER/$REPO${NC}"
        echo -e "${BLUE}PR: #$PR_NUM${NC}"
        return
    fi

    # Check if input is a number (PR number)
    if [[ "$INPUT" =~ ^[0-9]+$ ]]; then
        MODE="pr"
        PR_NUM="$INPUT"
        return
    fi

    # Invalid input
    echo -e "${RED}Error: Invalid input '$INPUT'${NC}"
    echo "Expected: PR number, PR URL, or GitHub workflow run URL"
    echo "Run with --help for usage information"
    exit 1
}

is_default_branch() {
    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

    # Check common default branch names
    if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
        return 0
    fi

    # Also check if this branch matches the remote's default
    local default_branch
    default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "")
    if [ -n "$default_branch" ] && [ "$current_branch" == "$default_branch" ]; then
        return 0
    fi

    return 1
}

determine_pr() {
    if [ -z "$PR_NUM" ]; then
        # Try to find PR for current branch
        # First try upstream (for fork workflows)
        if [ -n "$(git remote get-url upstream 2>/dev/null || echo "")" ]; then
            PR_NUM=$(gh pr view --repo "$OWNER/$REPO" --json number -q '.number' 2>/dev/null || echo "")
        fi
        # Fallback to origin
        if [ -z "$PR_NUM" ]; then
            PR_NUM=$(gh pr view --json number -q '.number' 2>/dev/null || echo "")
        fi
        if [ -z "$PR_NUM" ]; then
            echo -e "${RED}No PR found for current branch${NC}"
            echo "Tip: Specify PR number as argument: $(basename "$0") 29304"
            exit 1
        fi
    fi
}

# Handle branch mode (main/master without PR)
handle_branch_mode() {
    local current_branch head_sha
    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "HEAD")
    head_sha=$(git rev-parse HEAD 2>/dev/null)

    if [ -z "$head_sha" ]; then
        echo -e "${RED}Error: Could not determine HEAD commit${NC}"
        exit 1
    fi

    echo -e "${BLUE}Checking CI status for branch '$current_branch' in $OWNER/$REPO${NC}"
    echo -e "${BLUE}Commit: ${head_sha:0:12}${NC}"
    echo

    # Get workflow runs for this SHA
    local runs
    runs=$(gh api "repos/$OWNER/$REPO/actions/runs?head_sha=$head_sha&per_page=100" 2>/dev/null || echo '{"workflow_runs":[]}')

    local total_runs
    total_runs=$(echo "$runs" | jq -r '(.workflow_runs // []) | length')

    if [ "$total_runs" -eq 0 ]; then
        echo -e "${YELLOW}No workflow runs found for this commit${NC}"
        echo "This commit may not have any CI workflows, or they haven't started yet."
        echo
        echo "Check: https://github.com/$OWNER/$REPO/actions"
        exit 0
    fi

    # Check for in-progress runs
    local in_progress_count
    in_progress_count=$(echo "$runs" | jq -r '[(.workflow_runs // [])[] | select(.status == "in_progress" or .status == "queued")] | length')

    if [ "$in_progress_count" -gt 0 ]; then
        echo -e "${YELLOW}$in_progress_count workflow(s) still running...${NC}"
        echo "$runs" | jq -r '(.workflow_runs // [])[] | select(.status == "in_progress" or .status == "queued") | "  ⏳ \(.name) (\(.status))"'
        echo
    fi

    # Check for failures
    local failed_runs
    failed_runs=$(echo "$runs" | jq -r '[(.workflow_runs // [])[] | select(.conclusion == "failure")]')
    local failed_count
    failed_count=$(echo "$failed_runs" | jq -r 'length')

    # Check for successes
    local success_count
    success_count=$(echo "$runs" | jq -r '[(.workflow_runs // [])[] | select(.conclusion == "success")] | length')

    if [ "$failed_count" -eq 0 ]; then
        if [ "$in_progress_count" -gt 0 ]; then
            echo -e "${YELLOW}No failures yet, but $in_progress_count workflow(s) still running${NC}"
        else
            echo -e "${GREEN}✓ All $success_count workflow(s) passing${NC}"
        fi
        exit 0
    fi

    echo -e "${RED}Found $failed_count failing workflow(s):${NC}"
    echo "$failed_runs" | jq -r '.[] | "  ✗ \(.name)"'
    echo

    # Create temp directory for logs
    local log_dir
    log_dir=$(mktemp -d -t "ci-failures-${current_branch}-XXXXXX")
    echo -e "${BLUE}Saving logs to: $log_dir${NC}"
    echo

    # Get failed run IDs
    local failed_run_ids
    failed_run_ids=$(echo "$failed_runs" | jq -r '.[].id')

    # Save logs for each failed run
    local saved_count=0
    for run_id in $failed_run_ids; do
        local run_name
        run_name=$(echo "$runs" | jq -r ".workflow_runs[] | select(.id == $run_id) | .name")
        local safe_name
        safe_name=$(echo "$run_name" | tr ' /:()#' '_' | tr -cd '[:alnum:]_-' | head -c 50)
        local log_file="$log_dir/${safe_name}_${run_id}.log"

        echo -e "${YELLOW}Fetching logs: $run_name (run $run_id)${NC}"
        if gh run view "$run_id" --repo "$OWNER/$REPO" --log-failed > "$log_file" 2>/dev/null; then
            local line_count
            line_count=$(wc -l < "$log_file" | tr -d ' ')
            if [ "$line_count" -gt 0 ]; then
                echo -e "  ${GREEN}✓${NC} Saved: $(basename "$log_file") ($line_count lines)"
                ((saved_count++))
            else
                echo -e "  ${YELLOW}(empty log)${NC}"
                rm -f "$log_file"
            fi
        else
            echo -e "  ${RED}(failed to fetch)${NC}"
            rm -f "$log_file"
        fi
    done

    echo
    if [ "$saved_count" -gt 0 ]; then
        echo -e "${GREEN}Logs saved to: $log_dir${NC}"
        echo
        echo "Files:"
        ls -la "$log_dir"
        echo
        # Show preview of first error
        local first_log
        first_log=$(ls "$log_dir"/*.log 2>/dev/null | head -1)
        if [ -n "$first_log" ] && [ -f "$first_log" ]; then
            echo -e "${BLUE}Preview of $(basename "$first_log"):${NC}"
            echo "----------------------------------------"
            tail -100 "$first_log"
            echo "----------------------------------------"
        fi
    else
        echo -e "${YELLOW}No log files were saved${NC}"
        echo "Check: https://github.com/$OWNER/$REPO/actions?query=branch%3A$current_branch"
    fi

    exit 1
}

# Handle workflow run mode
handle_workflow_run() {
    echo -e "${BLUE}Fetching workflow run logs...${NC}"
    echo

    # Get run details
    local run_info
    run_info=$(gh api "repos/$OWNER/$REPO/actions/runs/$RUN_ID" 2>/dev/null)

    if [ -z "$run_info" ]; then
        echo -e "${RED}Error: Could not fetch workflow run information${NC}"
        echo "Run ID: $RUN_ID"
        echo "Repository: $OWNER/$REPO"
        exit 1
    fi

    local run_name conclusion status
    run_name=$(echo "$run_info" | jq -r '.name // "Unknown"')
    conclusion=$(echo "$run_info" | jq -r '.conclusion // "none"')
    status=$(echo "$run_info" | jq -r '.status // "unknown"')

    echo -e "${BLUE}Workflow: $run_name${NC}"
    echo -e "${BLUE}Status: $status${NC}"
    echo -e "${BLUE}Conclusion: $conclusion${NC}"
    echo

    # Create temp directory for logs
    local log_dir
    log_dir=$(mktemp -d -t "workflow-run-${RUN_ID}-XXXXXX")
    echo -e "${BLUE}Saving logs to: $log_dir${NC}"
    echo

    local safe_name
    safe_name=$(echo "$run_name" | tr ' /:()#' '_' | tr -cd '[:alnum:]_-' | head -c 50)
    local log_file="$log_dir/${safe_name}_${RUN_ID}.log"

    if [ "$conclusion" = "failure" ]; then
        echo -e "${YELLOW}Fetching failed job logs...${NC}"
        if gh run view "$RUN_ID" --repo "$OWNER/$REPO" --log-failed > "$log_file" 2>/dev/null; then
            local line_count
            line_count=$(wc -l < "$log_file" | tr -d ' ')
            if [ "$line_count" -gt 0 ]; then
                echo -e "  ${GREEN}✓${NC} Saved: $(basename "$log_file") ($line_count lines)"
            else
                echo -e "  ${YELLOW}(empty log - no failed jobs found)${NC}"
                rm -f "$log_file"
            fi
        else
            echo -e "  ${RED}✗ Failed to fetch logs${NC}"
            rm -f "$log_file"
        fi
    else
        echo -e "${YELLOW}Fetching all logs (run conclusion: $conclusion)...${NC}"
        if gh run view "$RUN_ID" --repo "$OWNER/$REPO" --log > "$log_file" 2>/dev/null; then
            local line_count
            line_count=$(wc -l < "$log_file" | tr -d ' ')
            if [ "$line_count" -gt 0 ]; then
                echo -e "  ${GREEN}✓${NC} Saved: $(basename "$log_file") ($line_count lines)"
            else
                echo -e "  ${YELLOW}(empty log)${NC}"
                rm -f "$log_file"
            fi
        else
            echo -e "  ${RED}✗ Failed to fetch logs${NC}"
            rm -f "$log_file"
        fi
    fi

    echo
    if [ -f "$log_file" ]; then
        echo -e "${GREEN}Logs saved to: $log_dir${NC}"
        echo
        echo "Files:"
        ls -la "$log_dir"
        echo
        # Show preview
        echo -e "${BLUE}Preview of $(basename "$log_file"):${NC}"
        echo "----------------------------------------"
        tail -100 "$log_file"
        echo "----------------------------------------"
        echo
        echo "View full log: $log_file"
        echo "Workflow URL: https://github.com/$OWNER/$REPO/actions/runs/$RUN_ID"
    else
        echo -e "${YELLOW}No logs were saved${NC}"
        echo "View online: https://github.com/$OWNER/$REPO/actions/runs/$RUN_ID"
    fi

    # Exit with appropriate code
    if [ "$conclusion" = "failure" ]; then
        exit 1
    else
        exit 0
    fi
}

main() {
    if ! command -v gh &> /dev/null; then
        echo -e "${RED}Error: GitHub CLI (gh) is not installed${NC}"
        exit 1
    fi

    parse_input

    # Handle workflow run mode
    if [ "$MODE" = "run" ]; then
        handle_workflow_run
        return
    fi

    # Handle PR mode (existing functionality)
    # Only get repo info from git if not already set from URL
    if [ -z "$OWNER" ] || [ -z "$REPO" ]; then
        get_repo_info
    fi

    # If no PR specified and on default branch, use branch mode
    if [ -z "$PR_NUM" ] && is_default_branch; then
        echo -e "${BLUE}On default branch - checking workflow runs directly${NC}"
        handle_branch_mode
        return
    fi

    determine_pr

    echo -e "${BLUE}Checking CI status for PR #$PR_NUM in $OWNER/$REPO${NC}"

    # Ensure PR directory exists
    create_pr_directory "$OWNER" "$REPO" "$PR_NUM"
    local pr_dir
    pr_dir=$(get_pr_dir_path "$OWNER" "$REPO" "$PR_NUM")

    # Get all checks
    local checks_output
    checks_output=$(gh pr checks "$PR_NUM" --repo "$OWNER/$REPO" 2>&1 || echo "")

    if [ -z "$checks_output" ] || [[ "$checks_output" == *"no checks"* ]]; then
        echo -e "${YELLOW}No checks found for this PR${NC}"
        exit 0
    fi

    # Find failing checks (match "fail" in status column)
    local failing_checks
    failing_checks=$(echo "$checks_output" | awk -F'\t' '$2 == "fail" || $2 ~ /fail/' || echo "")

    if [ -z "$failing_checks" ]; then
        echo -e "${GREEN}✓ All checks passing${NC}"
        # Update CI index even when passing
        local head_sha
        head_sha=$(gh pr view "$PR_NUM" --repo "$OWNER/$REPO" --json headRefOid -q '.headRefOid')
        local runs
        runs=$(gh api "repos/$OWNER/$REPO/actions/runs?head_sha=$head_sha&per_page=100" 2>/dev/null || echo '{"workflow_runs":[]}')
        write_ci_index "$OWNER" "$REPO" "$PR_NUM" "$runs"
        echo -e "${BLUE}Context: $pr_dir${NC}"
        exit 0
    fi

    local fail_count
    fail_count=$(echo "$failing_checks" | wc -l | tr -d ' ')
    echo -e "${RED}Found $fail_count failing check(s):${NC}"
    echo
    echo "$failing_checks" | while IFS=$'\t' read -r name status duration url; do
        echo -e "  ${RED}✗${NC} $name"
    done
    echo

    # Get HEAD SHA
    local head_sha
    head_sha=$(gh pr view "$PR_NUM" --repo "$OWNER/$REPO" --json headRefOid -q '.headRefOid')

    # Get workflow runs for this SHA
    local runs
    runs=$(gh api "repos/$OWNER/$REPO/actions/runs?head_sha=$head_sha&per_page=100" 2>/dev/null || echo '{"workflow_runs":[]}')

    # Write CI index
    write_ci_index "$OWNER" "$REPO" "$PR_NUM" "$runs"

    # Get failed run IDs
    local failed_run_ids
    failed_run_ids=$(echo "$runs" | jq -r '(.workflow_runs // [])[] | select(.conclusion == "failure") | .id' | sort -u)

    if [ -z "$failed_run_ids" ]; then
        echo -e "${YELLOW}No GitHub Actions workflow logs available${NC}"
        echo
        echo "Failing checks may be from external CI. Check URLs above or:"
        echo "  https://github.com/$OWNER/$REPO/pull/$PR_NUM/checks"
        echo
        # Still save the check output
        echo "$failing_checks" > "$pr_dir/ci/failing-checks.txt"
        echo -e "${GREEN}Check list saved to: $pr_dir/ci/failing-checks.txt${NC}"
        echo -e "${BLUE}Context: $pr_dir${NC}"
        exit 1
    fi

    echo -e "${BLUE}Saving logs to: $pr_dir/ci/${NC}"
    echo

    # Save logs for each failed run
    local saved_count=0
    for run_id in $failed_run_ids; do
        # Check if logs already downloaded (idempotent)
        if ci_logs_downloaded "$OWNER" "$REPO" "$PR_NUM" "$run_id"; then
            echo -e "${GREEN}✓ Already downloaded: run $run_id${NC}"
            ((saved_count++))
            continue
        fi

        local run_info
        run_info=$(echo "$runs" | jq ".workflow_runs[] | select(.id == $run_id)")
        local run_name
        run_name=$(echo "$run_info" | jq -r '.name')

        # Create run directory
        local run_dir
        run_dir=$(create_ci_run_directory "$OWNER" "$REPO" "$PR_NUM" "$run_info")

        local safe_name
        safe_name=$(echo "$run_name" | tr ' /:()#' '_' | tr -cd '[:alnum:]_-' | head -c 50)
        local log_file="$run_dir/${safe_name}.log"

        echo -e "${YELLOW}Fetching logs: $run_name (run $run_id)${NC}"
        local failed_jobs="[]"
        if gh run view "$run_id" --repo "$OWNER/$REPO" --log-failed > "$log_file" 2>/dev/null; then
            local line_count
            line_count=$(wc -l < "$log_file" | tr -d ' ')
            if [ "$line_count" -gt 0 ]; then
                echo -e "  ${GREEN}✓${NC} Saved: $(basename "$run_dir")/$(basename "$log_file") ($line_count lines)"
                ((saved_count++))
                # Extract failed job names from log
                failed_jobs=$(grep -E "^[A-Za-z0-9_-]+\t" "$log_file" 2>/dev/null | cut -f1 | sort -u | jq -R -s 'split("\n") | map(select(length > 0))' || echo "[]")
            else
                echo -e "  ${YELLOW}(empty log)${NC}"
                rm -f "$log_file"
            fi
        else
            echo -e "  ${RED}(failed to fetch)${NC}"
            rm -f "$log_file"
        fi
        # Mark logs as downloaded (idempotent for future runs)
        mark_ci_logs_downloaded "$OWNER" "$REPO" "$PR_NUM" "$run_id" "$failed_jobs"
    done

    echo
    if [ "$saved_count" -gt 0 ]; then
        echo -e "${GREEN}Logs saved to: $pr_dir/ci/${NC}"
        echo
        echo "Files:"
        ls -la "$pr_dir/ci/"
        echo
        # Show preview of first error from most recent run
        local latest_run_dir
        latest_run_dir=$(ls -dt "$pr_dir/ci/"*/  2>/dev/null | head -1)
        if [ -n "$latest_run_dir" ]; then
            local first_log
            first_log=$(ls "$latest_run_dir"/*.log 2>/dev/null | head -1)
            if [ -n "$first_log" ] && [ -f "$first_log" ]; then
                echo -e "${BLUE}Preview of $(basename "$latest_run_dir")/$(basename "$first_log"):${NC}"
                echo "----------------------------------------"
                tail -100 "$first_log"
                echo "----------------------------------------"
            fi
        fi
    else
        echo -e "${YELLOW}No log files were saved${NC}"
        echo "Check: https://github.com/$OWNER/$REPO/pull/$PR_NUM/checks"
    fi

    echo
    echo -e "${BLUE}Context directory: $pr_dir${NC}"
    exit 1
}

main "$@"
