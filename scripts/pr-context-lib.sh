#!/bin/bash

# PR Context Library
# Shared functions for managing PR context directory structure
# Used by: get-pr-context.sh, get-failing-checks.sh, create-pr workflows

# Prevent multiple sourcing
[[ -n "${_PR_CONTEXT_LIB_LOADED:-}" ]] && return 0
_PR_CONTEXT_LIB_LOADED=1

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Library version for compatibility checking
PR_CONTEXT_LIB_VERSION="1.0.0"

# Base directory for PR context storage
PR_CONTEXT_BASE="${PR_CONTEXT_BASE:-$HOME/.claude/prs}"

#######################################
# Get the PR directory path
# Arguments:
#   $1 - owner (e.g., "octocat")
#   $2 - repo (e.g., "hello-world")
#   $3 - PR number
# Outputs:
#   Path to PR directory
#######################################
get_pr_dir_path() {
    local owner="$1"
    local repo="$2"
    local pr_num="$3"
    echo "${PR_CONTEXT_BASE}/${owner}-${repo}/${pr_num}"
}

#######################################
# Create PR directory structure
# Arguments:
#   $1 - owner
#   $2 - repo
#   $3 - PR number
# Returns:
#   0 on success, 1 on failure
#######################################
create_pr_directory() {
    local owner="$1"
    local repo="$2"
    local pr_num="$3"
    local pr_dir
    pr_dir=$(get_pr_dir_path "$owner" "$repo" "$pr_num")

    mkdir -p "$pr_dir"/{reviews,threads,plans,ci}

    # Initialize status.json
    write_status "$owner" "$repo" "$pr_num" "fetching"
    return 0
}

#######################################
# Write status.json atomically
# Arguments:
#   $1 - owner
#   $2 - repo
#   $3 - PR number
#   $4 - state (fetching|complete|error)
#   $5 - error message (optional)
#######################################
write_status() {
    local owner="$1"
    local repo="$2"
    local pr_num="$3"
    local state="$4"
    local error="${5:-null}"
    local pr_dir
    pr_dir=$(get_pr_dir_path "$owner" "$repo" "$pr_num")
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local status_file="$pr_dir/status.json"
    local tmp_file
    tmp_file=$(mktemp)

    # Read existing status for timestamps
    local last_started last_completed
    if [[ -f "$status_file" ]]; then
        last_started=$(jq -r '.lastFetchStarted // ""' "$status_file" 2>/dev/null || echo "")
        last_completed=$(jq -r '.lastFetchCompleted // ""' "$status_file" 2>/dev/null || echo "")
    fi

    case "$state" in
        fetching)
            last_started="$now"
            ;;
        complete)
            last_completed="$now"
            ;;
        error)
            [[ "$error" == "null" ]] && error="Unknown error"
            ;;
    esac

    cat > "$tmp_file" <<EOF
{
  "state": "$state",
  "lastFetchStarted": "${last_started:-$now}",
  "lastFetchCompleted": ${last_completed:+\"$last_completed\"}${last_completed:-null},
  "error": ${error:+\"$error\"}${error:-null}
}
EOF

    mv "$tmp_file" "$status_file"
}

#######################################
# Write metadata.json with PR info
# Arguments:
#   $1 - owner
#   $2 - repo
#   $3 - PR number
#   $4 - JSON string with PR data from gh
#######################################
write_metadata() {
    local owner="$1"
    local repo="$2"
    local pr_num="$3"
    local pr_json="$4"
    local pr_dir
    pr_dir=$(get_pr_dir_path "$owner" "$repo" "$pr_num")
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local tmp_file
    tmp_file=$(mktemp)

    # Extract key fields and build metadata
    jq --arg fetched "$now" '{
        version: "1.0",
        fetchedAt: $fetched,
        pr: {
            number: .number,
            title: .title,
            state: .state,
            isDraft: .isDraft,
            author: .author.login,
            url: .url,
            headRefName: .headRefName,
            baseRefName: .baseRefName,
            mergeable: .mergeable,
            createdAt: .createdAt,
            updatedAt: .updatedAt
        },
        stats: {
            additions: .additions,
            deletions: .deletions,
            changedFiles: .changedFiles
        },
        labels: ([.labels[]?.name] // []),
        assignees: ([.assignees[]?.login] // []),
        milestone: .milestone.title
    }' <<< "$pr_json" > "$tmp_file"

    mv "$tmp_file" "$pr_dir/metadata.json"
}

#######################################
# Write description.md
# Arguments:
#   $1 - owner
#   $2 - repo
#   $3 - PR number
#   $4 - PR body text
#######################################
write_description() {
    local owner="$1"
    local repo="$2"
    local pr_num="$3"
    local body="$4"
    local pr_dir
    pr_dir=$(get_pr_dir_path "$owner" "$repo" "$pr_num")

    local tmp_file
    tmp_file=$(mktemp)

    echo "$body" > "$tmp_file"
    mv "$tmp_file" "$pr_dir/description.md"
}

#######################################
# Write files.json with changed files
# Arguments:
#   $1 - owner
#   $2 - repo
#   $3 - PR number
#   $4 - JSON array of files from gh
#######################################
write_files_json() {
    local owner="$1"
    local repo="$2"
    local pr_num="$3"
    local files_json="$4"
    local pr_dir
    pr_dir=$(get_pr_dir_path "$owner" "$repo" "$pr_num")

    local tmp_file
    tmp_file=$(mktemp)

    jq '[.[] | {
        path: .path,
        changeType: .changeType,
        additions: .additions,
        deletions: .deletions
    }]' <<< "$files_json" > "$tmp_file"

    mv "$tmp_file" "$pr_dir/files.json"
}

#######################################
# Write diff.patch (with truncation)
# Arguments:
#   $1 - owner
#   $2 - repo
#   $3 - PR number
#   $4 - diff content
#   $5 - max lines (default: 5000)
#######################################
write_diff() {
    local owner="$1"
    local repo="$2"
    local pr_num="$3"
    local diff="$4"
    local max_lines="${5:-5000}"
    local pr_dir
    pr_dir=$(get_pr_dir_path "$owner" "$repo" "$pr_num")

    local tmp_file
    tmp_file=$(mktemp)
    local total_lines
    total_lines=$(echo "$diff" | wc -l | tr -d ' ')

    if [[ "$total_lines" -gt "$max_lines" ]]; then
        echo "$diff" | head -n "$max_lines" > "$tmp_file"
        echo "" >> "$tmp_file"
        echo "# TRUNCATED: Showing $max_lines of $total_lines lines" >> "$tmp_file"
        echo "# Run 'gh pr diff $pr_num' for full diff" >> "$tmp_file"
    else
        echo "$diff" > "$tmp_file"
    fi

    mv "$tmp_file" "$pr_dir/diff.patch"
}

#######################################
# Check if PR data is stale
# Arguments:
#   $1 - owner
#   $2 - repo
#   $3 - PR number
#   $4 - PR updatedAt from GitHub
# Returns:
#   0 if stale (needs refresh), 1 if fresh
#######################################
is_pr_stale() {
    local owner="$1"
    local repo="$2"
    local pr_num="$3"
    local pr_updated_at="$4"
    local pr_dir
    pr_dir=$(get_pr_dir_path "$owner" "$repo" "$pr_num")

    local metadata_file="$pr_dir/metadata.json"
    if [[ ! -f "$metadata_file" ]]; then
        return 0  # No local data, needs fetch
    fi

    local local_fetched
    local_fetched=$(jq -r '.fetchedAt // ""' "$metadata_file" 2>/dev/null)
    if [[ -z "$local_fetched" ]]; then
        return 0  # No fetch timestamp, needs refresh
    fi

    # Compare timestamps (PR updated after we fetched = stale)
    if [[ "$pr_updated_at" > "$local_fetched" ]]; then
        return 0  # PR was updated, needs refresh
    fi

    # Also check if more than 1 hour old
    local fetched_epoch
    fetched_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$local_fetched" +%s 2>/dev/null || echo "0")
    local now_epoch
    now_epoch=$(date +%s)
    local age=$((now_epoch - fetched_epoch))

    if [[ "$age" -gt 3600 ]]; then
        return 0  # More than 1 hour old
    fi

    return 1  # Fresh enough
}

#######################################
# Atomic JSON file update (merge)
# Arguments:
#   $1 - file path
#   $2 - JSON to merge
#######################################
atomic_json_merge() {
    local file="$1"
    local new_json="$2"
    local tmp_file
    tmp_file=$(mktemp)

    if [[ -f "$file" ]]; then
        jq -s '.[0] * .[1]' "$file" - <<< "$new_json" > "$tmp_file"
    else
        echo "$new_json" > "$tmp_file"
    fi

    mv "$tmp_file" "$file"
}

#######################################
# Output section header (for terminal)
# Arguments:
#   $1 - section title
#######################################
section() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

#######################################
# Parse repository info from git
# Sets: OWNER, REPO global variables
# Returns:
#   0 on success, 1 on failure
#######################################
parse_repo_from_git() {
    local remote_url=""

    # Prefer upstream for fork workflows
    if git remote get-url upstream &>/dev/null; then
        remote_url=$(git remote get-url upstream)
    elif git remote get-url origin &>/dev/null; then
        remote_url=$(git remote get-url origin)
    else
        echo -e "${RED}Error: No git remotes found${NC}" >&2
        return 1
    fi

    # Parse SSH or HTTPS URL
    if [[ "$remote_url" =~ ^git@github.com:([^/]+)/([^/]+)(\.git)?$ ]]; then
        OWNER="${BASH_REMATCH[1]}"
        REPO="${BASH_REMATCH[2]%.git}"
    elif [[ "$remote_url" =~ ^https://github.com/([^/]+)/([^/]+)(\.git)?$ ]]; then
        OWNER="${BASH_REMATCH[1]}"
        REPO="${BASH_REMATCH[2]%.git}"
    else
        echo -e "${RED}Error: Not a GitHub repository${NC}" >&2
        return 1
    fi

    return 0
}

#######################################
# Parse PR URL to extract owner, repo, number
# Arguments:
#   $1 - URL string
# Sets: OWNER, REPO, PR_NUM
# Returns:
#   0 if valid PR URL, 1 otherwise
#######################################
parse_pr_url() {
    local url="$1"
    if [[ "$url" =~ ^https://github.com/([^/]+)/([^/]+)/pull/([0-9]+)(/.*)?$ ]]; then
        OWNER="${BASH_REMATCH[1]}"
        REPO="${BASH_REMATCH[2]}"
        PR_NUM="${BASH_REMATCH[3]}"
        return 0
    fi
    return 1
}

#######################################
# REVIEWS AND THREADS FUNCTIONS
#######################################

#######################################
# Fetch reviews and threads via GraphQL
# Arguments:
#   $1 - owner
#   $2 - repo
#   $3 - PR number
# Outputs:
#   JSON with reviews and threads
#######################################
fetch_reviews_and_threads() {
    local owner="$1"
    local repo="$2"
    local pr_num="$3"

    local query='query($owner: String!, $repo: String!, $pr: Int!) {
        repository(owner: $owner, name: $repo) {
            pullRequest(number: $pr) {
                comments(first: 100) {
                    nodes {
                        id
                        author { login }
                        body
                        createdAt
                        updatedAt
                    }
                }
                reviews(first: 100) {
                    nodes {
                        id
                        author { login }
                        body
                        state
                        submittedAt
                        comments(first: 100) {
                            nodes {
                                id
                                path
                                line
                                originalLine
                                body
                                createdAt
                                diffHunk
                            }
                        }
                    }
                }
                reviewThreads(first: 100) {
                    nodes {
                        id
                        isResolved
                        isOutdated
                        path
                        line
                        originalLine
                        comments(first: 50) {
                            nodes {
                                id
                                author { login }
                                body
                                createdAt
                            }
                        }
                    }
                }
            }
        }
    }'

    gh api graphql -F owner="$owner" -F repo="$repo" -F pr="$pr_num" -f query="$query" 2>/dev/null
}

#######################################
# Write PR discussion comments (non-review comments)
# Arguments:
#   $1 - owner
#   $2 - repo
#   $3 - PR number
#   $4 - data JSON from GraphQL
#######################################
write_discussion_comments() {
    local owner="$1"
    local repo="$2"
    local pr_num="$3"
    local data_json="$4"
    local pr_dir
    pr_dir=$(get_pr_dir_path "$owner" "$repo" "$pr_num")
    local comments_file="$pr_dir/comments.json"

    local tmp_file
    tmp_file=$(mktemp)

    echo "$data_json" | jq '{
        comments: [.data.repository.pullRequest.comments.nodes[]? | {
            id: .id,
            author: .author.login,
            body: .body,
            createdAt: .createdAt,
            updatedAt: .updatedAt
        }],
        count: (.data.repository.pullRequest.comments.nodes | length)
    }' > "$tmp_file"

    mv "$tmp_file" "$comments_file"
}

#######################################
# Write review files to reviews/ directory
# Arguments:
#   $1 - owner
#   $2 - repo
#   $3 - PR number
#   $4 - reviews JSON from GraphQL
#######################################
write_review_files() {
    local owner="$1"
    local repo="$2"
    local pr_num="$3"
    local reviews_json="$4"
    local pr_dir
    pr_dir=$(get_pr_dir_path "$owner" "$repo" "$pr_num")
    local reviews_dir="$pr_dir/reviews"

    # Parse and write each review
    echo "$reviews_json" | jq -c '.data.repository.pullRequest.reviews.nodes[]?' | while read -r review; do
        [[ -z "$review" || "$review" == "null" ]] && continue

        local review_id author state submitted_at body
        review_id=$(echo "$review" | jq -r '.id // ""')
        author=$(echo "$review" | jq -r '.author.login // "unknown"')
        state=$(echo "$review" | jq -r '.state // "COMMENTED"')
        submitted_at=$(echo "$review" | jq -r '.submittedAt // ""')
        body=$(echo "$review" | jq -r '.body // ""')

        # Skip empty reviews with no comments
        local comment_count
        comment_count=$(echo "$review" | jq '.comments.nodes | length')
        [[ -z "$body" && "$comment_count" -eq 0 ]] && continue

        # Create filename: timestamp-author-id.md
        local ts_safe
        ts_safe=$(echo "$submitted_at" | tr ':' '-' | cut -c1-19)
        local short_id
        short_id=$(echo "$review_id" | sed 's/.*_//' | head -c 8)
        local filename="${ts_safe}-${author}-${short_id}.md"
        local review_file="$reviews_dir/$filename"

        # Write review markdown
        {
            echo "# Review by @${author}"
            echo "**State:** ${state} | **Submitted:** ${submitted_at}"
            echo ""

            if [[ -n "$body" ]]; then
                echo "## General Comment"
                echo "$body"
                echo ""
            fi

            # Write inline comments from this review
            local comments
            comments=$(echo "$review" | jq -c '.comments.nodes[]?' 2>/dev/null)
            if [[ -n "$comments" ]]; then
                echo "## Inline Comments"
                echo ""
                echo "$review" | jq -c '.comments.nodes[]?' | while read -r comment; do
                    [[ -z "$comment" || "$comment" == "null" ]] && continue
                    local path line comment_body
                    path=$(echo "$comment" | jq -r '.path // ""')
                    line=$(echo "$comment" | jq -r '.line // .originalLine // "?"')
                    comment_body=$(echo "$comment" | jq -r '.body // ""')
                    echo "### \`${path}:${line}\`"
                    echo "> ${comment_body}"
                    echo ""
                done
            fi
        } > "$review_file"
    done
}

#######################################
# Write reviews/index.json
# Arguments:
#   $1 - owner
#   $2 - repo
#   $3 - PR number
#   $4 - reviews JSON from GraphQL
#######################################
write_reviews_index() {
    local owner="$1"
    local repo="$2"
    local pr_num="$3"
    local reviews_json="$4"
    local pr_dir
    pr_dir=$(get_pr_dir_path "$owner" "$repo" "$pr_num")
    local index_file="$pr_dir/reviews/index.json"

    # Read existing local statuses to preserve
    local existing_statuses="{}"
    if [[ -f "$index_file" ]]; then
        existing_statuses=$(jq '.reviews // {}' "$index_file" 2>/dev/null || echo "{}")
    fi

    local tmp_file
    tmp_file=$(mktemp)

    # Build index with preserved local status
    echo "$reviews_json" | jq --argjson existing "$existing_statuses" '
        .data.repository.pullRequest.reviews.nodes as $reviews |
        {
            reviews: ([$reviews[]? | {
                id: .id,
                author: .author.login,
                state: .state,
                submittedAt: .submittedAt,
                commentCount: (.comments.nodes | length),
                localStatus: (($existing[.id] // {}) | .localStatus // {addressed: false})
            }] | map({(.id): .}) | add // {}),
            summary: {
                total: ($reviews | length),
                approved: ([$reviews[]? | select(.state == "APPROVED")] | length),
                changesRequested: ([$reviews[]? | select(.state == "CHANGES_REQUESTED")] | length),
                commented: ([$reviews[]? | select(.state == "COMMENTED")] | length)
            }
        }
    ' > "$tmp_file"

    mv "$tmp_file" "$index_file"
}

#######################################
# Write threads/index.json with resolution tracking
# Arguments:
#   $1 - owner
#   $2 - repo
#   $3 - PR number
#   $4 - reviews JSON from GraphQL (contains threads)
#######################################
write_threads_index() {
    local owner="$1"
    local repo="$2"
    local pr_num="$3"
    local data_json="$4"
    local pr_dir
    pr_dir=$(get_pr_dir_path "$owner" "$repo" "$pr_num")
    local index_file="$pr_dir/threads/index.json"

    # Read existing local statuses to preserve
    local existing_statuses="{}"
    if [[ -f "$index_file" ]]; then
        existing_statuses=$(jq '.threads // {}' "$index_file" 2>/dev/null || echo "{}")
    fi

    local tmp_file
    tmp_file=$(mktemp)

    echo "$data_json" | jq --argjson existing "$existing_statuses" '
        .data.repository.pullRequest.reviewThreads.nodes as $threads |
        {
            threads: ([$threads[]? | {
                id: .id,
                path: .path,
                line: (.line // .originalLine),
                isResolved: .isResolved,
                isOutdated: .isOutdated,
                reviewer: (.comments.nodes[0]?.author.login // "unknown"),
                hasSuggestion: ((.comments.nodes[]?.body // "") | contains("```suggestion")),
                localStatus: (($existing[.id] // {}) | .localStatus // {addressed: false})
            }] | map({(.id): .}) | add // {}),
            summary: {
                total: ($threads | length),
                resolved: ([$threads[]? | select(.isResolved == true)] | length),
                pending: ([$threads[]? | select(.isResolved == false)] | length),
                outdated: ([$threads[]? | select(.isOutdated == true)] | length)
            },
            pendingByFile: (
                [$threads[]? | select(.isResolved == false)] |
                group_by(.path) |
                map({(.[0].path): length}) |
                add // {}
            )
        }
    ' > "$tmp_file"

    mv "$tmp_file" "$index_file"
}

#######################################
# Write individual thread files
# Arguments:
#   $1 - owner
#   $2 - repo
#   $3 - PR number
#   $4 - reviews JSON from GraphQL
#######################################
write_thread_files() {
    local owner="$1"
    local repo="$2"
    local pr_num="$3"
    local data_json="$4"
    local pr_dir
    pr_dir=$(get_pr_dir_path "$owner" "$repo" "$pr_num")
    local threads_dir="$pr_dir/threads"

    echo "$data_json" | jq -c '.data.repository.pullRequest.reviewThreads.nodes[]?' | while read -r thread; do
        [[ -z "$thread" || "$thread" == "null" ]] && continue

        local thread_id
        thread_id=$(echo "$thread" | jq -r '.id')
        local short_id
        short_id=$(echo "$thread_id" | sed 's/.*_//' | head -c 12)
        local thread_file="$threads_dir/${short_id}.json"

        echo "$thread" | jq '{
            id: .id,
            path: .path,
            line: (.line // .originalLine),
            isResolved: .isResolved,
            isOutdated: .isOutdated,
            comments: [.comments.nodes[]? | {
                id: .id,
                author: .author.login,
                body: .body,
                createdAt: .createdAt
            }]
        }' > "$thread_file"
    done
}

#######################################
# Mark a thread as addressed locally
# Arguments:
#   $1 - owner
#   $2 - repo
#   $3 - PR number
#   $4 - thread ID
#   $5 - commit SHA (optional)
# Returns:
#   0 on success, 1 if thread not found
#######################################
mark_thread_addressed() {
    local owner="$1"
    local repo="$2"
    local pr_num="$3"
    local thread_id="$4"
    local commit_sha="${5:-}"
    local pr_dir
    pr_dir=$(get_pr_dir_path "$owner" "$repo" "$pr_num")
    local index_file="$pr_dir/threads/index.json"

    if [[ ! -f "$index_file" ]]; then
        echo -e "${RED}Error: No thread index found. Run /pr-context first.${NC}" >&2
        return 1
    fi

    # Check if thread exists
    local thread_exists
    thread_exists=$(jq --arg id "$thread_id" '.threads[$id] // null' "$index_file")
    if [[ "$thread_exists" == "null" ]]; then
        echo -e "${RED}Error: Thread $thread_id not found${NC}" >&2
        return 1
    fi

    local tmp_file
    tmp_file=$(mktemp)
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    jq --arg id "$thread_id" --arg sha "$commit_sha" --arg ts "$now" '
        .threads[$id].localStatus = {
            addressed: true,
            addressedAt: $ts,
            addressedInCommit: (if $sha == "" then null else $sha end)
        }
    ' "$index_file" > "$tmp_file"

    mv "$tmp_file" "$index_file"
    echo -e "${GREEN}Marked thread $thread_id as addressed${NC}"
}

#######################################
# Get list of pending action items
# Arguments:
#   $1 - owner
#   $2 - repo
#   $3 - PR number
# Outputs:
#   Formatted list of pending items
#######################################
get_pending_items() {
    local owner="$1"
    local repo="$2"
    local pr_num="$3"
    local pr_dir
    pr_dir=$(get_pr_dir_path "$owner" "$repo" "$pr_num")
    local threads_index="$pr_dir/threads/index.json"
    local reviews_index="$pr_dir/reviews/index.json"

    echo -e "${BLUE}Pending Action Items for PR #${pr_num}${NC}"
    echo ""

    # Unresolved threads
    if [[ -f "$threads_index" ]]; then
        local pending_count
        pending_count=$(jq '.summary.pending // 0' "$threads_index")
        if [[ "$pending_count" -gt 0 ]]; then
            echo -e "${YELLOW}Unresolved Threads: $pending_count${NC}"
            jq -r '
                .threads | to_entries[] |
                select(.value.isResolved == false) |
                "  [\(.value.localStatus.addressed | if . then "LOCAL" else "PENDING" end)] \(.value.path):\(.value.line) (by @\(.value.reviewer))"
            ' "$threads_index"
            echo ""
        fi
    fi

    # Changes requested
    if [[ -f "$reviews_index" ]]; then
        local changes_requested
        changes_requested=$(jq '.summary.changesRequested // 0' "$reviews_index")
        if [[ "$changes_requested" -gt 0 ]]; then
            echo -e "${YELLOW}Changes Requested: $changes_requested${NC}"
            jq -r '
                .reviews | to_entries[] |
                select(.value.state == "CHANGES_REQUESTED") |
                "  @\(.value.author) at \(.value.submittedAt)"
            ' "$reviews_index"
        fi
    fi

    # Check for failing CI
    local ci_index="$pr_dir/ci/index.json"
    if [[ -f "$ci_index" ]]; then
        local failed_runs
        failed_runs=$(jq '[.runs[]? | select(.conclusion == "failure")] | length' "$ci_index")
        if [[ "$failed_runs" -gt 0 ]]; then
            echo -e "${RED}Failing CI Runs: $failed_runs${NC}"
            jq -r '.runs[] | select(.conclusion == "failure") | "  \(.name) (\(.createdAt))"' "$ci_index"
        fi
    fi
}

#######################################
# CI FUNCTIONS
#######################################

#######################################
# Get CI run directory path
# Arguments:
#   $1 - owner
#   $2 - repo
#   $3 - PR number
#   $4 - run ID
#   $5 - created_at timestamp
# Outputs:
#   Path to CI run directory
#######################################
get_ci_run_dir() {
    local owner="$1"
    local repo="$2"
    local pr_num="$3"
    local run_id="$4"
    local created_at="$5"
    local pr_dir
    pr_dir=$(get_pr_dir_path "$owner" "$repo" "$pr_num")

    # Format: YYYY-MM-DDTHHMMSS-runid
    local ts_safe
    ts_safe=$(echo "$created_at" | tr ':' '' | cut -c1-17 | tr -d '-' | head -c 15)
    echo "$pr_dir/ci/${ts_safe}-${run_id}"
}

#######################################
# Create CI run directory and write summary
# Arguments:
#   $1 - owner
#   $2 - repo
#   $3 - PR number
#   $4 - run info JSON
# Returns:
#   Path to run directory
#######################################
create_ci_run_directory() {
    local owner="$1"
    local repo="$2"
    local pr_num="$3"
    local run_info="$4"

    local run_id created_at
    run_id=$(echo "$run_info" | jq -r '.id')
    created_at=$(echo "$run_info" | jq -r '.created_at // .createdAt // ""')

    local run_dir
    run_dir=$(get_ci_run_dir "$owner" "$repo" "$pr_num" "$run_id" "$created_at")
    mkdir -p "$run_dir"

    # Write summary.json
    echo "$run_info" | jq '{
        id: .id,
        name: .name,
        status: .status,
        conclusion: .conclusion,
        createdAt: (.created_at // .createdAt),
        updatedAt: (.updated_at // .updatedAt),
        htmlUrl: (.html_url // .htmlUrl),
        headSha: (.head_sha // .headSha),
        jobs: (.jobs // [])
    }' > "$run_dir/summary.json"

    echo "$run_dir"
}

#######################################
# Write ci/index.json with run tracking
# Arguments:
#   $1 - owner
#   $2 - repo
#   $3 - PR number
#   $4 - runs JSON array from GitHub API
#######################################
write_ci_index() {
    local owner="$1"
    local repo="$2"
    local pr_num="$3"
    local runs_json="$4"
    local pr_dir
    pr_dir=$(get_pr_dir_path "$owner" "$repo" "$pr_num")
    local index_file="$pr_dir/ci/index.json"

    # Read existing index to preserve logsDownloaded status
    local existing_runs="{}"
    if [[ -f "$index_file" ]]; then
        existing_runs=$(jq '.runs | map({(.id | tostring): .}) | add // {}' "$index_file" 2>/dev/null || echo "{}")
    fi

    local tmp_file
    tmp_file=$(mktemp)
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    echo "$runs_json" | jq --argjson existing "$existing_runs" --arg fetched "$now" '
        {
            fetchedAt: $fetched,
            runs: [.workflow_runs[]? | {
                id: .id,
                name: .name,
                status: .status,
                conclusion: .conclusion,
                createdAt: .created_at,
                directory: ((.created_at | gsub("[:-]"; "") | .[0:15]) + "-" + (.id | tostring)),
                failedJobs: (if .conclusion == "failure" then [] else null end),
                logsDownloaded: (($existing[.id | tostring].logsDownloaded) // false)
            }],
            summary: {
                total: [.workflow_runs[]?] | length,
                success: [.workflow_runs[]? | select(.conclusion == "success")] | length,
                failure: [.workflow_runs[]? | select(.conclusion == "failure")] | length,
                pending: [.workflow_runs[]? | select(.status == "in_progress" or .status == "queued")] | length
            }
        }
    ' > "$tmp_file"

    mv "$tmp_file" "$index_file"
}

#######################################
# Mark CI run logs as downloaded
# Arguments:
#   $1 - owner
#   $2 - repo
#   $3 - PR number
#   $4 - run ID
#   $5 - failed jobs array (JSON)
#######################################
mark_ci_logs_downloaded() {
    local owner="$1"
    local repo="$2"
    local pr_num="$3"
    local run_id="$4"
    local failed_jobs="${5:-[]}"
    local pr_dir
    pr_dir=$(get_pr_dir_path "$owner" "$repo" "$pr_num")
    local index_file="$pr_dir/ci/index.json"

    if [[ ! -f "$index_file" ]]; then
        return 1
    fi

    local tmp_file
    tmp_file=$(mktemp)

    jq --arg id "$run_id" --argjson jobs "$failed_jobs" '
        .runs = [.runs[] |
            if (.id | tostring) == $id then
                . + {logsDownloaded: true, failedJobs: $jobs}
            else
                .
            end
        ]
    ' "$index_file" > "$tmp_file"

    mv "$tmp_file" "$index_file"
}

#######################################
# Check if CI logs already downloaded for run
# Arguments:
#   $1 - owner
#   $2 - repo
#   $3 - PR number
#   $4 - run ID
# Returns:
#   0 if already downloaded, 1 otherwise
#######################################
ci_logs_downloaded() {
    local owner="$1"
    local repo="$2"
    local pr_num="$3"
    local run_id="$4"
    local pr_dir
    pr_dir=$(get_pr_dir_path "$owner" "$repo" "$pr_num")
    local index_file="$pr_dir/ci/index.json"

    if [[ ! -f "$index_file" ]]; then
        return 1
    fi

    local downloaded
    downloaded=$(jq --arg id "$run_id" '
        [.runs[] | select((.id | tostring) == $id and .logsDownloaded == true)] | length > 0
    ' "$index_file")

    [[ "$downloaded" == "true" ]]
}

#######################################
# OVERVIEW GENERATION
#######################################

#######################################
# Generate overview.md (auto-generated entry point for Claude)
# Arguments:
#   $1 - owner
#   $2 - repo
#   $3 - PR number
#######################################
generate_overview() {
    local owner="$1"
    local repo="$2"
    local pr_num="$3"
    local pr_dir
    pr_dir=$(get_pr_dir_path "$owner" "$repo" "$pr_num")
    local overview_file="$pr_dir/overview.md"

    local tmp_file
    tmp_file=$(mktemp)
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Start building overview
    {
        echo "# PR #${pr_num} Overview"
        echo ""
        echo "_Generated: ${now}_"
        echo "_Directory: ${pr_dir}_"
        echo ""

        # PR Info from metadata
        if [[ -f "$pr_dir/metadata.json" ]]; then
            local title state author url additions deletions files
            title=$(jq -r '.pr.title // "Unknown"' "$pr_dir/metadata.json")
            state=$(jq -r '.pr.state // "Unknown"' "$pr_dir/metadata.json")
            author=$(jq -r '.pr.author // "Unknown"' "$pr_dir/metadata.json")
            url=$(jq -r '.pr.url // ""' "$pr_dir/metadata.json")
            additions=$(jq -r '.stats.additions // 0' "$pr_dir/metadata.json")
            deletions=$(jq -r '.stats.deletions // 0' "$pr_dir/metadata.json")
            files=$(jq -r '.stats.changedFiles // 0' "$pr_dir/metadata.json")

            echo "## Summary"
            echo ""
            echo "**${title}**"
            echo ""
            echo "| Field | Value |"
            echo "|-------|-------|"
            echo "| State | ${state} |"
            echo "| Author | @${author} |"
            echo "| Changes | +${additions} -${deletions} across ${files} files |"
            [[ -n "$url" ]] && echo "| URL | ${url} |"
            echo ""
        fi

        # Action Items
        echo "## Action Items"
        echo ""

        local has_actions=false

        # Pending threads
        if [[ -f "$pr_dir/threads/index.json" ]]; then
            local pending_threads
            pending_threads=$(jq '.summary.pending // 0' "$pr_dir/threads/index.json")
            if [[ "$pending_threads" -gt 0 ]]; then
                has_actions=true
                echo "### Unresolved Review Threads: ${pending_threads}"
                echo ""
                jq -r '
                    .threads | to_entries[] |
                    select(.value.isResolved == false) |
                    "- [ ] `\(.value.path):\(.value.line)` by @\(.value.reviewer)" +
                    (if .value.localStatus.addressed then " *(locally addressed)*" else "" end)
                ' "$pr_dir/threads/index.json"
                echo ""
            fi
        fi

        # Changes requested
        if [[ -f "$pr_dir/reviews/index.json" ]]; then
            local changes_requested
            changes_requested=$(jq '.summary.changesRequested // 0' "$pr_dir/reviews/index.json")
            if [[ "$changes_requested" -gt 0 ]]; then
                has_actions=true
                echo "### Changes Requested: ${changes_requested}"
                echo ""
                jq -r '
                    .reviews | to_entries[] |
                    select(.value.state == "CHANGES_REQUESTED") |
                    "- [ ] @\(.value.author) (\(.value.submittedAt | split("T")[0]))"
                ' "$pr_dir/reviews/index.json"
                echo ""
            fi
        fi

        # Failing CI
        if [[ -f "$pr_dir/ci/index.json" ]]; then
            local failing_ci
            failing_ci=$(jq '.summary.failure // 0' "$pr_dir/ci/index.json")
            if [[ "$failing_ci" -gt 0 ]]; then
                has_actions=true
                echo "### Failing CI: ${failing_ci}"
                echo ""
                jq -r '
                    .runs[] | select(.conclusion == "failure") |
                    "- [ ] \(.name) - logs in `ci/\(.directory)/`"
                ' "$pr_dir/ci/index.json"
                echo ""
            fi
        fi

        if [[ "$has_actions" == "false" ]]; then
            echo "✅ No pending action items"
            echo ""
        fi

        # Review Status
        echo "## Review Status"
        echo ""
        if [[ -f "$pr_dir/reviews/index.json" ]]; then
            local approved commented
            approved=$(jq '.summary.approved // 0' "$pr_dir/reviews/index.json")
            commented=$(jq '.summary.commented // 0' "$pr_dir/reviews/index.json")
            echo "- Approvals: ${approved}"
            echo "- Comments: ${commented}"
            echo ""
            echo "See \`reviews/\` for individual review files."
        else
            echo "No reviews fetched yet."
        fi
        echo ""

        # Discussion Comments (non-review)
        if [[ -f "$pr_dir/comments.json" ]]; then
            local comment_count
            comment_count=$(jq '.count // 0' "$pr_dir/comments.json")
            if [[ "$comment_count" -gt 0 ]]; then
                echo "## Discussion Comments: ${comment_count}"
                echo ""
                jq -r '.comments[]? | "- @\(.author) (\(.createdAt | split("T")[0])): \(.body | split("\n")[0] | .[0:80])..."' "$pr_dir/comments.json" 2>/dev/null || true
                echo ""
                echo "See \`comments.json\` for full comment text."
                echo ""
            fi
        fi

        # CI Status
        echo "## CI Status"
        echo ""
        if [[ -f "$pr_dir/ci/index.json" ]]; then
            local ci_success ci_failure ci_pending
            ci_success=$(jq '.summary.success // 0' "$pr_dir/ci/index.json")
            ci_failure=$(jq '.summary.failure // 0' "$pr_dir/ci/index.json")
            ci_pending=$(jq '.summary.pending // 0' "$pr_dir/ci/index.json")
            echo "- ✅ Passing: ${ci_success}"
            echo "- ❌ Failing: ${ci_failure}"
            echo "- ⏳ Pending: ${ci_pending}"
            echo ""
            echo "See \`ci/\` for logs."
        else
            echo "No CI data fetched yet."
        fi
        echo ""

        # Files needing attention
        if [[ -f "$pr_dir/threads/index.json" ]]; then
            local pending_by_file
            pending_by_file=$(jq '.pendingByFile // {}' "$pr_dir/threads/index.json")
            if [[ "$pending_by_file" != "{}" ]]; then
                echo "## Files Needing Attention"
                echo ""
                jq -r 'to_entries[] | "- `\(.key)`: \(.value) unresolved thread(s)"' <<< "$pending_by_file"
                echo ""
            fi
        fi

        # Quick Links
        echo "## Quick Reference"
        echo ""
        echo "| File | Purpose |"
        echo "|------|---------|"
        echo "| \`metadata.json\` | PR info, stats, timestamps |"
        echo "| \`description.md\` | PR body/description |"
        echo "| \`files.json\` | Changed files list |"
        echo "| \`diff.patch\` | Full diff |"
        echo "| \`comments.json\` | PR discussion comments |"
        echo "| \`reviews/index.json\` | Review tracking |"
        echo "| \`threads/index.json\` | Thread resolution tracking |"
        echo "| \`ci/index.json\` | CI run tracking |"
        echo "| \`plans/\` | Related planning docs |"

    } > "$tmp_file"

    mv "$tmp_file" "$overview_file"
}

#######################################
# PLANNING DOCS DETECTION
#######################################

#######################################
# Detect and copy planning docs to PR directory
# Arguments:
#   $1 - owner
#   $2 - repo
#   $3 - PR number
#   $4 - repo root directory (optional, defaults to cwd)
#######################################
detect_and_copy_planning_docs() {
    local owner="$1"
    local repo="$2"
    local pr_num="$3"
    local repo_root="${4:-.}"
    local pr_dir
    pr_dir=$(get_pr_dir_path "$owner" "$repo" "$pr_num")
    local plans_dir="$pr_dir/plans"

    # Standard locations to check
    local search_dirs=(".dev/specs" "docs" "planning" "dev/efas" "design" "specs")

    # Patterns to match (case-insensitive)
    local patterns=("design" "plan" "spec" "rfc" "proposal" "adr")

    local copied_count=0

    for search_dir in "${search_dirs[@]}"; do
        local full_path="$repo_root/$search_dir"
        [[ ! -d "$full_path" ]] && continue

        # Find relevant files
        while IFS= read -r -d '' file; do
            local basename
            basename=$(basename "$file")
            local basename_lower
            basename_lower=$(echo "$basename" | tr '[:upper:]' '[:lower:]')

            # Check if filename matches any pattern
            local matches=false
            for pattern in "${patterns[@]}"; do
                if [[ "$basename_lower" == *"$pattern"* ]]; then
                    matches=true
                    break
                fi
            done

            if [[ "$matches" == "true" ]]; then
                # Copy file preserving relative path
                local rel_path="${file#$repo_root/}"
                local dest_dir
                dest_dir=$(dirname "$plans_dir/$rel_path")
                mkdir -p "$dest_dir"
                cp "$file" "$plans_dir/$rel_path"
                ((copied_count++))
            fi
        done < <(find "$full_path" -type f \( -name "*.md" -o -name "*.txt" -o -name "*.adoc" \) -print0 2>/dev/null)
    done

    # Also check PR description for linked docs
    if [[ -f "$pr_dir/description.md" ]]; then
        # Extract file paths mentioned in description
        local linked_files
        linked_files=$(grep -oE '\b[a-zA-Z0-9_/-]+\.(md|txt|adoc)\b' "$pr_dir/description.md" 2>/dev/null || true)
        for linked in $linked_files; do
            if [[ -f "$repo_root/$linked" ]]; then
                local dest_dir
                dest_dir=$(dirname "$plans_dir/$linked")
                mkdir -p "$dest_dir"
                cp "$repo_root/$linked" "$plans_dir/$linked" 2>/dev/null || true
                ((copied_count++))
            fi
        done
    fi

    if [[ "$copied_count" -gt 0 ]]; then
        echo -e "${GREEN}Copied $copied_count planning doc(s) to $plans_dir${NC}"
    fi
}
