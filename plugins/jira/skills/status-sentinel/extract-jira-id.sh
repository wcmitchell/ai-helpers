#!/bin/bash
# Extract JIRA ID from various sources
# Usage: extract-jira-id.sh [--branch name] [--commits N]

set -euo pipefail

# Configuration
DEFAULT_COMMIT_SCAN_DEPTH=20

# Parse arguments
BRANCH="${1:-$(git branch --show-current 2>/dev/null || echo '')}"
COMMIT_DEPTH="${2:-$DEFAULT_COMMIT_SCAN_DEPTH}"

# JIRA ID pattern: PROJECT-NUMBER (uppercase letters, hyphen, digits)
# Examples: ENGPROD-1234, OCPBUGS-5678, HYPE-999
JIRA_PATTERN='[A-Z][A-Z0-9]+-[0-9]+'

extract_from_branch() {
  local branch="$1"
  echo "$branch" | grep -oP "$JIRA_PATTERN" | head -1 || true
}

extract_from_git_config() {
  local branch="$1"
  git config "branch.${branch}.jira" 2>/dev/null || true
}

extract_from_commits() {
  local depth="$1"
  git log -"$depth" --pretty=format:"%s" 2>/dev/null | \
    grep -oP "$JIRA_PATTERN" | \
    head -1 || true
}

# Detection cascade
detect_jira_id() {
  local branch="$1"
  local jira_id=""

  # 1. Try branch name (highest confidence)
  jira_id=$(extract_from_branch "$branch")
  if [ -n "$jira_id" ]; then
    echo "$jira_id"
    echo "source: branch_name" >&2
    echo "confidence: high" >&2
    return 0
  fi

  # 2. Try git config (user-specified)
  jira_id=$(extract_from_git_config "$branch")
  if [ -n "$jira_id" ]; then
    echo "$jira_id"
    echo "source: git_config" >&2
    echo "confidence: high" >&2
    return 0
  fi

  # 3. Try commit messages (medium confidence)
  jira_id=$(extract_from_commits "$COMMIT_DEPTH")
  if [ -n "$jira_id" ]; then
    echo "$jira_id"
    echo "source: commit_messages" >&2
    echo "confidence: medium" >&2
    return 0
  fi

  # Not found
  echo "source: none" >&2
  echo "confidence: none" >&2
  return 1
}

# Main
if [ -z "$BRANCH" ]; then
  echo "Error: Not in a git repository or no branch specified" >&2
  exit 1
fi

detect_jira_id "$BRANCH"
