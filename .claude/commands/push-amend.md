---
description: Amend the HEAD commit with all session changes and a freshly written commit message, then push (force-push with lease if it was already pushed).
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Edit
  - Write
---

# Push (Amend)

Fold all of this session's changes into the **HEAD commit**, rewrite its
message from scratch, and push. This rewrites history, so it force-pushes
**with lease** when the commit was already published and pushes normally
otherwise. Runs autonomously — no confirmation prompts.

Execute every step below in order.

## Step 1 — Fix lint errors

Before staging, find the project's lint target (`Taskfile.yml`, `Makefile`,
`justfile`, `package.json` scripts, `build.gradle`, `pom.xml`) — e.g. `task
lint`, `make lint`, `npm run lint`, `bun run lint` — and run it. Fix every
error, including pre-existing ones, and re-run until lint passes. Skip this
step only if no lint target exists.

## Step 2 — Capture pre-amend state

```bash
ORIG_HEAD=$(git rev-parse HEAD)
BRANCH=$(git branch --show-current)
# Parent = base of the amended commit; empty-tree hash if HEAD is the root commit
PARENT=$(git rev-parse --verify -q HEAD~1 || git hash-object -t tree /dev/null)
```

`ORIG_HEAD` is the commit you are about to amend; remember it for the push
decision in Step 6.

## Step 3 — Stage this session's changes

Stage **only the files this session changed**, by explicit path. Do **not**
use `git add -A`, `git add .`, or `git add -u`: in a home-directory or
dotfiles repo `git add -A` / `.` would sweep in thousands of unrelated
untracked files, and `-u` can sweep in unrelated tracked edits.

1. List what changed and identify the files that belong to this session's
   work (cross-check against what you actually edited or created):
   ```bash
   git status --porcelain=v1 -u
   ```
2. Stage exactly those files by path:
   ```bash
   git add -- <path>...
   ```
3. Review the staged set and confirm it contains only the intended changes —
   nothing from `.Trash`, caches, history, or unrelated directories:
   ```bash
   git diff --cached --stat
   ```
   Unstage anything that slipped in with `git restore --staged -- <path>`.

The staged set is what the final report describes as folded in. If you end
up with nothing staged and the tree was already clean, the amend simply
rewrites the message — still valid.

## Step 4 — Write a fresh commit message

Inspect the full content the amended commit will contain:

```bash
git diff --cached "$PARENT"
```

Write the commit message **from scratch** — conventional-commit format
(`<type>(<scope>): <subject>`), imperative subject under 72 characters, a body
that explains the *why* for non-trivial changes, matching the style of recent
`git log` (per the `how-to-commit` rule).

**Describe the amended commit's full content as one unified message organized by
*what the code does* (subject areas, behaviors) — never as a changelog of how it
was built.** No process-narration headings ("review pass", "follow-up",
"deep-review", "cleanup", "amendments", …). When the commit already has a body,
fold your changes into its thematic sections and drop any such headings it
carried rather than bolting a new block on top; the result must read as though
written in a single pass, with no trace it was assembled by amending.

Emit the message to a temp file:

```bash
MSG_FILE=$(mktemp -t push-amend-msg)
cat << 'MSG_EOF' >| "$MSG_FILE"
<type>(<scope>): <subject>

<body>
MSG_EOF
```

## Step 5 — Amend

```bash
git commit --amend -F "$MSG_FILE"; rm -f "$MSG_FILE"
NEW_HEAD=$(git rev-parse HEAD)
```

## Step 6 — Push (autonomous)

```bash
git fetch origin
if ! git ls-remote --heads origin "$BRANCH" | grep -q .; then
  git push -u origin "$BRANCH"                                          # not on remote → normal push
else
  REMOTE_SHA=$(git rev-parse "origin/$BRANCH")
  if [ "$REMOTE_SHA" = "$ORIG_HEAD" ]; then
    git push --force-with-lease="$BRANCH:$REMOTE_SHA" origin "$BRANCH"  # was pushed → force with lease
  elif git merge-base --is-ancestor "$ORIG_HEAD" "$REMOTE_SHA"; then
    echo "ABORT: origin/$BRANCH has commits not in local history; refusing to force-push." >&2
    # stop and report — do NOT push (would delete remote-only commits)
  else
    git push origin "$BRANCH"                                           # previous commit not pushed → normal push
  fi
fi
```

Why this works:

- **`REMOTE_SHA == ORIG_HEAD`** means the commit you just amended was the
  pushed tip, so the rewrite needs a force-push. The pinned lease
  `"$BRANCH:$REMOTE_SHA"` makes git reject the push if anyone pushed between
  your `fetch` and your `push` — never escalate a rejection to `--force`.
- **`ORIG_HEAD` is an ancestor of `REMOTE_SHA`** means the remote has commits
  you don't. Force-pushing would delete them, so abort and report instead —
  the user must reconcile first.
- **Otherwise** the amended commit was never pushed, so a normal push
  applies.

## Step 7 — Report

Report `ORIG_HEAD → NEW_HEAD` (short SHAs), the new subject line, which push
path ran (normal push / force-with-lease / aborted), and the branch and
remote.
