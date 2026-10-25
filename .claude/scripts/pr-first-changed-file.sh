#!/usr/bin/env bash
#
# Returns the first changed file in a PR (sorted like GitHub's file tree).
# Ignores deleted files, linguist-generated files, binary files, and -diff files.
#
# Usage: pr-first-changed-file.sh --pr <number> [--repo <owner/repo>]

set -euo pipefail

REPO=""
PR_NUMBER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="$2"
      shift 2
      ;;
    --pr)
      PR_NUMBER="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: pr-first-changed-file.sh --pr <number> [--repo <owner/repo>]" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$PR_NUMBER" ]]; then
  echo "Usage: pr-first-changed-file.sh --pr <number> [--repo <owner/repo>]" >&2
  exit 1
fi

if [[ -z "$REPO" ]]; then
  REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
fi

API_PATH="repos/$REPO/pulls/$PR_NUMBER/files"

# Build patterns for files to ignore (generated, binary, -diff)
build_ignore_patterns() {
  local patterns=""

  # Built-in patterns for common generated/binary files
  patterns="\.lock$|\.min\.(js|css)$"
  # Common binary file extensions
  patterns="$patterns|\\.(png|jpe?g|gif|ico|webp|svg|bmp|tiff?)$"
  patterns="$patterns|\\.(woff2?|ttf|otf|eot)$"
  patterns="$patterns|\\.(zip|tar|gz|bz2|xz|rar|7z)$"
  patterns="$patterns|\\.(pdf|doc|docx|xls|xlsx|ppt|pptx)$"
  patterns="$patterns|\\.(exe|dll|so|dylib|a|o)$"
  patterns="$patterns|\\.(jar|war|class)$"
  patterns="$patterns|\\.(mp3|mp4|wav|avi|mov|mkv|webm)$"

  # Parse gitattributes file and extract patterns for linguist-generated, binary, or -diff
  parse_gitattributes() {
    local file="$1"
    if [[ -f "$file" ]]; then
      # Match lines with linguist-generated, binary, or -diff
      grep -E '(linguist-generated(=true)?|binary|-diff)(\s|$)' "$file" 2>/dev/null | \
        awk '{print $1}' | \
        sed 's/\./\\./g; s/\*/.*/g; s/\?/./g' | \
        tr '\n' '|' | sed 's/|$//'
    fi
  }

  # Check global gitattributes
  local global_pattern=""
  if [[ -f "$HOME/.config/git/attributes" ]]; then
    global_pattern=$(parse_gitattributes "$HOME/.config/git/attributes")
  elif [[ -f "$HOME/.gitattributes" ]]; then
    global_pattern=$(parse_gitattributes "$HOME/.gitattributes")
  fi

  # Check repo's .gitattributes via API
  local repo_pattern=""
  repo_pattern=$(gh api "repos/$REPO/contents/.gitattributes" --jq '.content' 2>/dev/null | \
    base64 -d 2>/dev/null | \
    grep -E '(linguist-generated(=true)?|binary|-diff)(\s|$)' | \
    awk '{print $1}' | \
    sed 's/\./\\./g; s/\*/.*/g; s/\?/./g' | \
    tr '\n' '|' | sed 's/|$//' || true)

  # Combine all patterns
  [[ -n "$global_pattern" ]] && patterns="$patterns|$global_pattern"
  [[ -n "$repo_pattern" ]] && patterns="$patterns|$repo_pattern"

  echo "$patterns"
}

IGNORE_PATTERN=$(build_ignore_patterns)

# Fetch files, filter out deleted/generated/binary/-diff files, sort like GitHub
gh api "$API_PATH" --paginate --jq '.[] | select(.status != "removed") | .filename' | \
  grep -v -E "$IGNORE_PATTERN" | \
  awk '{
    n = split($0, parts, "/")
    key = ""
    for (i = 1; i <= n; i++) {
      if (i < n) {
        key = key "0" parts[i] "/"
      } else {
        key = key "1" parts[i]
      }
    }
    print key "\t" $0
  }' | \
  sort | \
  head -n 1 | \
  cut -f2
