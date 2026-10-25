---
description: Finish session work end-to-end — add and tighten tests for the changes, then amend the HEAD commit with a fresh message and push (force-push with lease if already pushed).
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Edit
  - Write
---

# Wrap Up (Amend)

Finish this session's work in one shot: strengthen tests for the changes,
then fold everything — code **and** the new tests — into the HEAD commit with
a fresh message and push. This composes two existing commands as the single
source of truth; do not reimplement their logic here.

**Ordering invariant:** tests run **before** the amend, so the new and
updated tests are folded into the same commit.

## Step 1 — Tests

Read `~/.claude/commands/tighten-tests.md` and execute every step against
this session's changes.

## Step 2 — Amend & push

Read `~/.claude/commands/push-amend.md` and execute every step. When you
reach its staging step, include the test files written in Step 1 among the
explicit paths you stage, so they are folded into the amended commit and its
message reflects the code and tests together.

## Step 3 — Combined report

Report both phases: the tests added/tightened/fixed, then the amend and push
outcome (`ORIG_HEAD → NEW_HEAD`, new subject line, push path).
