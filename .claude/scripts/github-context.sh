#!/usr/bin/env bash
#
# github-context.sh - Gather GitHub repository context
#
# Usage: github-context.sh
#
# Outputs GitHub context in a structured format for use by Claude Code commands.
#

set -euo pipefail

# Step 1: Check if in a git repository
if ! git rev-parse --git-dir &>/dev/null; then
  echo "ERROR: Not in a git repository"
  exit 1
fi

# Step 2: Get remote URL and parse GitHub info
REMOTE_URL=$(git remote get-url origin 2>/dev/null) || {
  echo "ERROR: No 'origin' remote found"
  exit 1
}

# Extract host from any format:
# - user@host:path (e.g., git@github.com:owner/repo.git)
# - host:path (e.g., github.com:owner/repo.git)
# - scheme://host/path (e.g., https://github.com/owner/repo.git)
GH_HOST=$(echo "$REMOTE_URL" | sed -E -e 's|^[a-z]+://||' -e 's|^([^@]+@)?([^:/]+)[:/].*|\2|')
OWNER_REPO=$(echo "$REMOTE_URL" | sed -E -e 's|^[a-z]+://||' -e 's|^([^@]+@)?[^:/]+[:/]||' -e 's|\.git$||')
OWNER=$(echo "$OWNER_REPO" | cut -d'/' -f1)
REPO=$(echo "$OWNER_REPO" | cut -d'/' -f2)

export GH_HOST

# Step 3: Check if repository is a fork
# Explicitly specify the repo from origin to avoid using a previously set default
FORK_INFO=$(gh repo view "$OWNER/$REPO" --json isFork,parent 2>/dev/null) || {
  echo "ERROR: GitHub CLI failed - unable to get repository info"
  exit 1
}

IS_FORK=$(echo "$FORK_INFO" | jq -r '.isFork')

if [[ "$IS_FORK" == "true" ]]; then
  UPSTREAM_OWNER=$(echo "$FORK_INFO" | jq -r '.parent.owner.login')
  UPSTREAM_REPO=$(echo "$FORK_INFO" | jq -r '.parent.name')
  UPSTREAM_REMOTE="upstream"
else
  UPSTREAM_OWNER="$OWNER"
  UPSTREAM_REPO="$REPO"
  UPSTREAM_REMOTE="origin"
fi

# Step 4: Configure remotes for forks
if [[ "$IS_FORK" == "true" ]]; then
  UPSTREAM_URL="https://$GH_HOST/$UPSTREAM_OWNER/$UPSTREAM_REPO.git"

  # Check if upstream remote exists
  if git remote get-url upstream &>/dev/null; then
    # Update if pointing to wrong URL
    CURRENT_UPSTREAM=$(git remote get-url upstream)
    if [[ "$CURRENT_UPSTREAM" != "$UPSTREAM_URL" && "$CURRENT_UPSTREAM" != "git@$GH_HOST:$UPSTREAM_OWNER/$UPSTREAM_REPO.git" ]]; then
      git remote set-url upstream "$UPSTREAM_URL"
    fi
  else
    # Add upstream remote
    git remote add upstream "$UPSTREAM_URL"
  fi

  # Fetch from upstream (suppress output)
  git fetch upstream --quiet 2>/dev/null || true
fi

# Step 5: Set default repository for gh
gh repo set-default "$UPSTREAM_OWNER/$UPSTREAM_REPO" --silent 2>/dev/null || true

# Step 6: Get branch info
BRANCH=$(git branch --show-current)

# Get default branch of upstream/target repo
DEFAULT_BRANCH=$(gh api "repos/$UPSTREAM_OWNER/$UPSTREAM_REPO" --jq '.default_branch' 2>/dev/null) || DEFAULT_BRANCH="main"

# Step 7: Find PR (if requested)
PR_NUMBER="none"
PR_TITLE="none"
PR_URL="none"
PR_BASE="none"

PR_INFO=$(gh pr view --json number,title,url,baseRefName 2>/dev/null) || PR_INFO=""

if [[ -n "$PR_INFO" ]]; then
  PR_NUMBER=$(echo "$PR_INFO" | jq -r '.number')
  PR_TITLE=$(echo "$PR_INFO" | jq -r '.title')
  PR_URL=$(echo "$PR_INFO" | jq -r '.url')
  PR_BASE=$(echo "$PR_INFO" | jq -r '.baseRefName')
fi

# Output
cat <<EOF
=== GITHUB CONTEXT ===
GH_HOST: $GH_HOST
OWNER: $OWNER
REPO: $REPO
BRANCH: $BRANCH
IS_FORK: $IS_FORK
UPSTREAM_OWNER: $UPSTREAM_OWNER
UPSTREAM_REPO: $UPSTREAM_REPO
UPSTREAM_REMOTE: $UPSTREAM_REMOTE
DEFAULT_BRANCH: $DEFAULT_BRANCH
PR_NUMBER: $PR_NUMBER
PR_TITLE: $PR_TITLE
PR_URL: $PR_URL
PR_BASE: $PR_BASE
EOF
