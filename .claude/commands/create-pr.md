---
description: Creates a new PR for the current branch with generated title and description
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Glob
  - Grep
  - Task
  - AskUserQuestion
---

# Create PR

You are helping the user create a new PR for their current branch with an appropriate title and description.

## Step 1: Fix Lint Errors

Before anything else, ensure there are no lint errors in the project:

1. Detect the project's build system (e.g., `Taskfile.yml`, `Makefile`, `justfile`, `package.json` scripts, `build.gradle`, `pom.xml`) and find the lint target (e.g., `task lint`, `make lint`, `npm run lint`, `bun run lint`).
2. Run the lint command.
3. If lint reports errors, fix all of them — including pre-existing ones — and re-run lint until it passes.
4. Once lint passes, proceed to Step 2.

If no lint target is found, skip this step.

## Step 2: Check Working Copy First

Before gathering any other context, check if the working copy is clean:

```bash
git status --porcelain
```

If there are uncommitted changes (output is not empty):
1. Show the list of uncommitted files
2. Use `AskUserQuestion` to ask the user what to do:
   ```json
   {
     "questions": [{
       "question": "There are uncommitted changes. What would you like to do?",
       "header": "Uncommitted",
       "multiSelect": false,
       "options": [
         {"label": "Commit changes (Recommended)", "description": "Create a commit with all uncommitted changes, then continue creating the PR"},
         {"label": "Cancel", "description": "Stop and let me handle the changes manually"}
       ]
     }]
   }
   ```
3. If user selects "Commit changes": Stage all modified/untracked files shown, generate an appropriate commit message following the repository's commit conventions, create the commit, and continue to Step 3.
4. If user selects "Cancel" or wants to handle it manually: Stop.

## Step 3: Gather GitHub Context

Run the GitHub context script:

```bash
~/.claude/scripts/github-context.sh
```

Parse the output and store these values for later use:
- `OWNER`, `REPO` - the current repository (may be a fork)
- `UPSTREAM_OWNER`, `UPSTREAM_REPO` - the target repository for PRs
- `UPSTREAM_REMOTE` - git remote name for upstream ("upstream" for forks, "origin" otherwise)
- `IS_FORK` - whether this is a fork
- `BRANCH`, `DEFAULT_BRANCH` - branch information

### 3a. Check Branch
If the current branch equals the default branch, inform the user they need to create a feature branch first and stop.

### 3b. Check No Existing PR
If a PR already exists for this branch (PR_NUMBER is not "none"):
- Inform the user and show the existing PR URL
- Suggest using `/update-pr-description` instead
- Stop

## Step 4: Push Commits

Check if there are unpushed commits:

```bash
# Fetch to ensure we have latest remote state
git fetch origin

# Get current branch
BRANCH=$(git branch --show-current)

# Check if branch exists on remote
git ls-remote --heads origin "$BRANCH"

# If branch exists on remote, check for unpushed commits
git log "origin/$BRANCH...HEAD" --oneline 2>/dev/null || echo "Branch not on remote yet"
```

If there are unpushed commits or the branch doesn't exist on remote, push the branch:

```bash
BRANCH=$(git branch --show-current)
git push -u origin "$BRANCH"
```

## Step 5: Generate Title and Description

### Step 5a: Gather stats

Run the following command:

```bash
git diff "$UPSTREAM_REMOTE/$DEFAULT_BRANCH...HEAD" --stat
```

Store the output as `DIFF_STATS`.

### Step 5b: Partition files and launch Explore agents

Parse the `--stat` output to get the list of changed files with their line counts.

**Partitioning strategy:**
1. Group files by top-level directory (or second-level if the first is generic like `src/`, `lib/`, `app/`)
2. Determine the number of agents based on PR size:
   - **Small** (≤10 files): 1 agent
   - **Medium** (11-30 files): 2-3 agents
   - **Large** (31+ files): up to 5 agents
3. Merge small groups together so each agent has a meaningful amount of work
4. Keep related files (same directory/module) together in the same group

**Launch Explore agents in parallel** using multiple Task tool calls (subagent_type=`Explore`) in a single message. Each agent receives a prompt constructed from this template:

````
Summarize the changes in these files for a PR description.

## Your Assigned Files
```
<SUBSET_OF_DIFF_STAT for this group>
```

## Instructions
1. Run: git diff "$UPSTREAM_REMOTE/$DEFAULT_BRANCH...HEAD" -- <file1> <file2> ...
   (substitute actual remote, branch, and file paths)
2. Read the most important changed files if the diff alone is insufficient to understand context
3. Produce a summary in this format:

=== CHANGE SUMMARY ===
## Files Analyzed
- <file> (+N, -M) ...

## Key Changes
- <2-5 bullets: what changed and why>

## Notable Details
- Breaking changes: <list or "None">
- Deprecations: <list or "None">
- New public APIs/features: <list or "None">
- Bug fixes: <list or "None">
````

Collect the output from all Explore agents as `CHANGE_SUMMARIES`.

### Step 5c: Invoke `_pr-description-generator`

Use the Task tool with subagent_type=`_pr-description-generator`. Pass:
- `DIFF_STATS`: from Step 5a
- `CHANGE_SUMMARIES`: collected from Step 5b

Parse the agent's output to extract the generated title and description.

**IMPORTANT**: Preserve the original Motivation-Modifications-Result structure of the generated description. Do NOT summarize, shorten, or restructure it. However, if there are factual inaccuracies (e.g., claiming code was added when it already existed, or mischaracterizing what a change does), fix them so the description accurately reflects the actual diff. Minor cleanup (e.g., fixing obvious typos or formatting) is also acceptable.

## Step 6: Present for Approval

Display the generated title and description to the user. If this is a fork, clearly indicate the PR target:

```
## Proposed New PR

**Repository**: <UPSTREAM_OWNER/UPSTREAM_REPO> (if fork, mention "from fork OWNER/REPO")
**Branch**: <branch name> → <default branch>

### Title
<generated title>

### Description

<generated description>
```

Then use `AskUserQuestion` for approval:

```json
{
  "questions": [{
    "question": "Do you want to create this PR?",
    "header": "Create PR",
    "multiSelect": false,
    "options": [
      {"label": "Create PR (Recommended)", "description": "Create the PR with the proposed title and description"},
      {"label": "Cancel", "description": "Don't create the PR"}
    ]
  }]
}
```

If user selects "Other" to request edits, apply their requested changes and ask again. If "Cancel", stop.

## Step 7: Create the PR

After user approval, create the PR.

**For forks**: Use `--repo` to target the upstream repository and `--head` to specify the fork's branch:

```bash
BODY_FILE=$(mktemp -t create-pr-description)
cat << 'BODY_EOF' >| "$BODY_FILE"
<generated description content>
BODY_EOF

# For forks: --repo targets upstream, --head specifies fork_owner:branch
gh pr create --repo "$UPSTREAM_OWNER/$UPSTREAM_REPO" --head "$OWNER:$BRANCH" --title "$TITLE" --body-file "$BODY_FILE" --base "$DEFAULT_BRANCH"
ret=$?; /bin/rm -f "$BODY_FILE"; exit $ret
```

**For non-forks**: Standard PR creation:

```bash
BODY_FILE=$(mktemp -t create-pr-description)
cat << 'BODY_EOF' >| "$BODY_FILE"
<generated description content>
BODY_EOF

gh pr create --title "$TITLE" --body-file "$BODY_FILE" --base "$DEFAULT_BRANCH"
ret=$?; /bin/rm -f "$BODY_FILE"; exit $ret
```

**Note**: Use `--body-file` instead of `--body` to handle multi-line content and special characters properly.

Report success and show the created PR URL.
