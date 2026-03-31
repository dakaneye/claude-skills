#!/usr/bin/env bash
# gh-issue.sh - Fetch comprehensive GitHub issue context
#
# Description: Retrieves issue metadata, description, comments, and all relevant
#              context using the GitHub CLI (gh) and formats it as markdown.
#
# Usage: gh-issue.sh [OPTIONS] <issue_number_or_url>
#
# Requirements:
#   - GitHub CLI (gh) installed and authenticated
#   - jq for JSON parsing
#
# Author: Claude Code
# Version: 1.0.0

set -Eeuo pipefail

# Enable better error handling in Bash 4.4+
if [[ "${BASH_VERSINFO[0]}" -ge 4 && "${BASH_VERSINFO[1]}" -ge 4 ]]; then
  shopt -s inherit_errexit
fi

# Set safer word splitting behavior
IFS=$'\n\t'

# Script metadata
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_VERSION="1.0.0"

# Global variables
REPO=""
ISSUE_NUMBER=""
ISSUE_URL=""

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

#######################################
# Print error message to stderr and exit
# Globals:
#   RED, NC
# Arguments:
#   Error message
# Outputs:
#   Writes error to stderr
#######################################
error() {
  printf -- "${RED}Error:${NC} %s\n" "$*" >&2
  exit 1
}

#######################################
# Print warning message to stderr
# Globals:
#   YELLOW, NC
# Arguments:
#   Warning message
# Outputs:
#   Writes warning to stderr
#######################################
warn() {
  printf -- "${YELLOW}Warning:${NC} %s\n" "$*" >&2
}

#######################################
# Print info message to stderr
# Globals:
#   BLUE, NC
# Arguments:
#   Info message
# Outputs:
#   Writes info to stderr
#######################################
info() {
  printf -- "${BLUE}Info:${NC} %s\n" "$*" >&2
}

#######################################
# Print success message to stderr
# Globals:
#   GREEN, NC
# Arguments:
#   Success message
# Outputs:
#   Writes success to stderr
#######################################
success() {
  printf -- "${GREEN}Success:${NC} %s\n" "$*" >&2
}

#######################################
# Display usage information
# Outputs:
#   Writes usage to stdout
#######################################
usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS] <issue_number_or_url>

Fetch comprehensive GitHub issue context including metadata, description,
comments, and all relevant information.

ARGUMENTS:
  issue_number_or_url   Issue number (e.g., 123) or full GitHub URL
                        (e.g., https://github.com/owner/repo/issues/123)

OPTIONS:
  -r, --repo REPO       Specify repository (default: auto-detect from git remote)
  -h, --help            Display this help message
  -v, --version         Display version information

EXAMPLES:
  # Fetch issue (repo auto-detected from git remote)
  ${SCRIPT_NAME} 123

  # Fetch issue from explicit repo
  ${SCRIPT_NAME} 456 --repo owner/repo
  ${SCRIPT_NAME} --repo owner/repo 456

  # Fetch issue using full GitHub URL (repo extracted automatically)
  ${SCRIPT_NAME} https://github.com/owner/repo/issues/789

  # Display help
  ${SCRIPT_NAME} --help

REQUIREMENTS:
  - GitHub CLI (gh) installed and authenticated
  - jq for JSON parsing

OUTPUT:
  Markdown-formatted issue context written to stdout

EOF
}

#######################################
# Display version information
# Outputs:
#   Writes version to stdout
#######################################
version() {
  printf -- "%s version %s\n" "${SCRIPT_NAME}" "${SCRIPT_VERSION}"
}

#######################################
# Check if required commands are available
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   0 if all required commands exist, 1 otherwise
#######################################
check_dependencies() {
  local missing_deps=()

  for cmd in gh jq; do
    if ! command -v "${cmd}" &>/dev/null; then
      missing_deps+=("${cmd}")
    fi
  done

  if [[ "${#missing_deps[@]}" -gt 0 ]]; then
    error "Missing required dependencies: ${missing_deps[*]}"
  fi

  # Check if gh is authenticated
  if ! gh auth status &>/dev/null; then
    error "GitHub CLI (gh) is not authenticated. Run 'gh auth login' first."
  fi
}

#######################################
# Detect repository from git remote
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Writes owner/repo to stdout, empty if not detected
#######################################
detect_repo_from_git() {
  local remote_url
  remote_url=$(git remote get-url origin 2>/dev/null || echo "")

  if [[ -z "${remote_url}" ]]; then
    return 1
  fi

  # Parse various GitHub URL formats
  if [[ "${remote_url}" =~ github\.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
    echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    return 0
  fi

  return 1
}

#######################################
# Extract repo and issue number from GitHub URL
# Globals:
#   REPO, ISSUE_NUMBER
# Arguments:
#   GitHub URL
# Returns:
#   0 on success, 1 on failure
#######################################
parse_github_url() {
  local url="$1"

  # Match GitHub issue URL pattern
  if [[ "${url}" =~ ^https?://github\.com/([^/]+/[^/]+)/issues/([0-9]+) ]]; then
    REPO="${BASH_REMATCH[1]}"
    ISSUE_NUMBER="${BASH_REMATCH[2]}"
    return 0
  else
    error "Invalid GitHub URL format: ${url}"
  fi
}

#######################################
# Parse command line arguments
# Globals:
#   REPO, ISSUE_NUMBER, ISSUE_URL
# Arguments:
#   Command line arguments
# Returns:
#   0 on success, 1 on failure
#######################################
parse_args() {
  local positional_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage
        exit 0
        ;;
      -v|--version)
        version
        exit 0
        ;;
      -r|--repo)
        if [[ -z "${2:-}" ]]; then
          error "Option $1 requires an argument"
        fi
        REPO="$2"
        shift 2
        ;;
      -*)
        error "Unknown option: $1"
        ;;
      *)
        positional_args+=("$1")
        shift
        ;;
    esac
  done

  # Check if we have exactly one positional argument
  if [[ "${#positional_args[@]}" -ne 1 ]]; then
    error "Expected exactly one argument (issue number or URL), got ${#positional_args[@]}"
  fi

  local arg="${positional_args[0]}"

  # Determine if argument is a URL or issue number
  if [[ "${arg}" =~ ^https?:// ]]; then
    parse_github_url "${arg}"
  elif [[ "${arg}" =~ ^[0-9]+$ ]]; then
    ISSUE_NUMBER="${arg}"
  else
    error "Invalid argument: ${arg} (expected issue number or GitHub URL)"
  fi

  # Auto-detect repo from git if not set
  if [[ -z "${REPO}" ]]; then
    if REPO=$(detect_repo_from_git); then
      info "Detected repository: ${REPO}"
    else
      error "No repository specified and could not detect from git remote. Use --repo or provide a full GitHub URL."
    fi
  fi
}

#######################################
# Format timestamp to readable date
# Arguments:
#   ISO 8601 timestamp
# Outputs:
#   Writes formatted date to stdout
#######################################
format_timestamp() {
  local timestamp="$1"

  if [[ -n "${timestamp}" && "${timestamp}" != "null" ]]; then
    # BSD (macOS) then GNU (Linux) date fallback
    date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "${timestamp}" "+%Y-%m-%d %H:%M:%S UTC" 2>/dev/null \
      || date -u -d "${timestamp}" "+%Y-%m-%d %H:%M:%S UTC" 2>/dev/null \
      || echo "${timestamp}"
  else
    echo "N/A"
  fi
}

#######################################
# Fetch and format issue data
# Globals:
#   REPO, ISSUE_NUMBER
# Arguments:
#   None
# Outputs:
#   Writes formatted markdown to stdout
#######################################
fetch_issue() {
  info "Fetching issue #${ISSUE_NUMBER} from ${REPO}..."

  # Fetch issue data
  local issue_json
  local json_fields="number,title,body,state,stateReason,author,createdAt,updatedAt,closedAt,url,labels,assignees,milestone,projectItems,comments,reactionGroups"
  if ! issue_json=$(gh issue view "${ISSUE_NUMBER}" --repo "${REPO}" --json "${json_fields}" 2>&1); then
    error "Failed to fetch issue: ${issue_json}"
  fi

  # Extract fields
  local number title body state state_reason author created updated closed url
  number=$(jq -r '.number' <<<"${issue_json}")
  title=$(jq -r '.title' <<<"${issue_json}")
  body=$(jq -r '.body // "No description provided."' <<<"${issue_json}")
  state=$(jq -r '.state' <<<"${issue_json}")
  state_reason=$(jq -r '.stateReason // "N/A"' <<<"${issue_json}")
  author=$(jq -r '.author.login' <<<"${issue_json}")
  created=$(jq -r '.createdAt' <<<"${issue_json}")
  updated=$(jq -r '.updatedAt' <<<"${issue_json}")
  closed=$(jq -r '.closedAt // "null"' <<<"${issue_json}")
  url=$(jq -r '.url' <<<"${issue_json}")

  # Format timestamps
  local created_fmt updated_fmt closed_fmt
  created_fmt=$(format_timestamp "${created}")
  updated_fmt=$(format_timestamp "${updated}")
  closed_fmt=$(format_timestamp "${closed}")

  # Start markdown output
  cat <<EOF
# Issue #${number}: ${title}

## Metadata

- **Repository**: ${REPO}
- **URL**: ${url}
- **State**: ${state}
- **State Reason**: ${state_reason}
- **Author**: @${author}
- **Created**: ${created_fmt}
- **Updated**: ${updated_fmt}
EOF

  if [[ "${closed}" != "null" ]]; then
    printf -- "- **Closed**: %s\n" "${closed_fmt}"
  fi

  printf -- "\n"

  # Assignees
  local assignees
  assignees=$(jq -r '.assignees | if length > 0 then [.[] | "@" + .login] | join(", ") else "None" end' <<<"${issue_json}")
  printf -- "- **Assignees**: %s\n" "${assignees}"

  # Labels
  local labels
  labels=$(jq -r '.labels | if length > 0 then [.[] | "`" + .name + "`"] | join(", ") else "None" end' <<<"${issue_json}")
  printf -- "- **Labels**: %s\n" "${labels}"

  # Milestone
  local milestone
  milestone=$(jq -r '.milestone.title // "None"' <<<"${issue_json}")
  printf -- "- **Milestone**: %s\n" "${milestone}"

  # Projects
  local projects
  projects=$(jq -r '.projectItems | if length > 0 then [.[] | .project.title] | join(", ") else "None" end' <<<"${issue_json}")
  printf -- "- **Projects**: %s\n\n" "${projects}"

  # Reactions
  local reactions
  reactions=$(jq -r '.reactionGroups | if length > 0 then [.[] | select(.users.totalCount > 0) | .content + " (" + (.users.totalCount | tostring) + ")"] | join(", ") else "None" end' <<<"${issue_json}")
  printf -- "- **Reactions**: %s\n\n" "${reactions}"

  # Issue body
  cat <<EOF
## Description

${body}

EOF

  # Comments
  local comment_count
  comment_count=$(jq -r '.comments | length' <<<"${issue_json}")

  if [[ "${comment_count}" -gt 0 ]]; then
    printf -- "## Comments (%d)\n\n" "${comment_count}"

    jq -r '.comments[] |
      "### Comment by @" + .author.login + " on " + .createdAt + "\n\n" +
      (.body // "*(No content)*") + "\n\n" +
      (if .reactions | length > 0 then
        "**Reactions**: " + ([.reactions[] | .content + " (" + (.count | tostring) + ")"] | join(", ")) + "\n\n"
       else "" end) +
      "---\n"' <<<"${issue_json}"
  else
    printf -- "## Comments\n\nNo comments.\n\n"
  fi

  success "Issue context fetched successfully"
}

#######################################
# Main function
# Arguments:
#   Command line arguments
# Returns:
#   0 on success, 1 on failure
#######################################
main() {
  check_dependencies
  parse_args "$@"
  fetch_issue
}

# Execute main function with all arguments
main "$@"
