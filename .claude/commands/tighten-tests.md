---
description: Add happy-path and edge-case tests, tighten existing tests, and fix tautological tests for the changes made in this session.
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Edit
  - Write
argument-hint: "[<target>]"
---

# Tighten Tests

Strengthen the test coverage for the changes made in this session. **If
feasible and non-preexisting**, add happy-path and edge-case tests, tighten
existing tests, and fix tautological tests — only coverage that does not
already exist and that the project's harness and fixtures can actually
support.

Execute every step below in order.

## Step 1 — Determine the change scope

If `$ARGUMENTS` is non-empty, treat it as the review target (branch, commit,
or path) and use `git diff <argument>` as the scope; skip the detection
below.

Otherwise run `git status --porcelain=v1 -u` once (the `-u` flag lists
individual files inside untracked directories rather than collapsing them to
a single `?? dir/` entry) and branch on the result:

- **Clean working tree** (no output) → the session's work is the last
  commit: `git show HEAD` gives the commit metadata and full diff in one
  call.
- **Dirty working tree** (any output) → every uncommitted change, staged +
  unstaged + untracked:
  - `git diff --cached` (staged)
  - `git diff` (unstaged tracked)
  - For each untracked file (lines starting with `??`):
    `git diff --no-index /dev/null <path> || true` — the trailing `|| true`
    is required because `git diff --no-index` exits non-zero whenever it
    finds differences, which is always the case here.

Treat this combined diff as the scope. Read each touched **non-test** source
file in full — coverage gaps in unchanged lines of a touched function are in
scope too.

## Step 2 — Add, tighten, and fix tests

For the code changed in this session (not pre-existing untouched code), when
feasible:

- Add **happy-path** tests for any new behavior that lacks one.
- Add **edge-case** tests for the boundary conditions the diff exposes
  (empty input, zero, negative, very large, concurrent, missing optional
  field, error path).
- **Tighten** existing tests that pass tautologically (assertion that always
  holds, mock that returns the value being asserted, test that only
  exercises the happy frame of a branch).
- **Fix** tautological tests outright.

Do not add a test that already exists, and do not invent coverage the
harness cannot support — that is what "feasible and non-preexisting" means.

## Step 3 — Discover the test command

Discover the project's test command first by checking `package.json`'s
`scripts.test`, `Taskfile.yml`, `Makefile`, `justfile`, `build.gradle` /
`pom.xml`, `pyproject.toml` / `uv` config, or similar. If no project-level
test target exists, fall back to invoking the language's test runner
directly on the test files you wrote or touched (e.g.
`pytest path/to/test_file.py`, `go test ./path/...`, `cargo test --test
foo`). If neither path works, note "no test runner available" in the final
report and stop trying — don't fabricate a command.

## Step 4 — Run the tests

Once the command is known, run it after each test addition or fix. If a test
fails, root-cause it before continuing — no retry loops, no skipping.

If a test is genuinely impractical (no harness, no fixtures, the change is
config-only, etc.), say so explicitly in the final report instead of
silently dropping it.

## Step 5 — Report

Report what you added, tightened, or fixed — one line per test with the file
and what it covers — and call out anything you judged impractical or
pre-existing and therefore skipped.
