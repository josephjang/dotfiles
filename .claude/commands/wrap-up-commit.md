---
description: Finish session work end-to-end — add and tighten tests for the changes, then commit everything as a new commit with a fresh message and push.
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Edit
  - Write
---

# Wrap Up (Commit)

Finish this session's work in one shot: strengthen tests for the changes,
then capture everything — code **and** the new tests — in a single new commit
with a fresh message and push. This composes two existing commands as the
single source of truth; do not reimplement their logic here.

**Ordering invariant:** tests run **before** the commit, so the new and
updated tests land in the same commit.

## Step 1 — Tests

Read `~/.claude/commands/tighten-tests.md` and execute every step against
this session's changes.

## Step 2 — Commit & push

Read `~/.claude/commands/push-commit.md` and execute every step. When you
reach its staging step, include the test files written in Step 1 among the
explicit paths you stage, so the single new commit captures the code and
tests together and its message reflects both.

## Step 3 — Combined report

Report both phases: the tests added/tightened/fixed, then the new commit
(short SHA, subject line) and push outcome.
