---
description: Commit all session changes as a new commit with a freshly written message, then push.
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Edit
  - Write
---

# Push (Commit)

The new-commit counterpart to `/push-amend`: stage this session's changes
into a **brand-new commit** with a freshly written message and push. Because
it adds history rather than rewriting it, it never force-pushes. Runs
autonomously.

Execute every step below in order.

## Step 1 — Fix lint errors

Before staging, find the project's lint target (`Taskfile.yml`, `Makefile`,
`justfile`, `package.json` scripts, `build.gradle`, `pom.xml`) — e.g. `task
lint`, `make lint`, `npm run lint`, `bun run lint` — and run it. Fix every
error, including pre-existing ones, and re-run until lint passes. Skip this
step only if no lint target exists.

## Step 2 — Stage this session's changes

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

If nothing ends up staged (`git diff --cached --quiet` exits 0), there is
nothing to commit — report that and **stop**. Unlike an amend, a new commit
needs content; it cannot just rewrite a message.

## Step 3 — Write a fresh commit message

Inspect the new commit's content — only the newly staged delta, not HEAD's
prior content:

```bash
git diff --cached
```

Write a commit message **from scratch** following the `how-to-commit` rule:
conventional-commit format (`<type>(<scope>): <subject>`), imperative subject
under 72 characters, and a body explaining the *why* for non-trivial changes.
Match recent `git log` style. Emit it to a temp file:

```bash
MSG_FILE=$(mktemp -t push-commit-msg)
cat << 'MSG_EOF' >| "$MSG_FILE"
<type>(<scope>): <subject>

<body>
MSG_EOF
```

## Step 4 — Commit

```bash
git commit -F "$MSG_FILE"; rm -f "$MSG_FILE"
NEW_HEAD=$(git rev-parse HEAD)
```

## Step 5 — Push (fast-forward only; never force)

```bash
git fetch origin
BRANCH=$(git branch --show-current)
if ! git ls-remote --heads origin "$BRANCH" | grep -q .; then
  git push -u origin "$BRANCH"          # not on remote → normal push, set upstream
else
  git push origin "$BRANCH"             # fast-forward; if remote diverged, git rejects it
fi
```

If git rejects the push as non-fast-forward (the remote has commits you
don't), report it and **stop** — do not force or auto-merge. Adding a commit
never rewrites published history.

## Step 6 — Report

Report the new commit's short SHA, its subject line, the push outcome
(normal push / set-upstream / rejected), and the branch and remote.
