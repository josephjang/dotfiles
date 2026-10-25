---
description: Updates the current PR's title and description based on all changes
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Task
  - AskUserQuestion
---

# Update PR Description

You are helping the user update their PR's title and description to accurately reflect all changes in the PR.

## Step 1: Check Working Copy First

Before gathering any other context, check if the working copy is clean:

```bash
git status --porcelain
```

If there are uncommitted changes (output is not empty):
1. Show the list of uncommitted files
2. Inform the user: "Please commit or stash your changes before updating the PR description."
3. Stop

## Step 2: Gather GitHub Context

Run the GitHub context script:

```bash
~/.claude/scripts/github-context.sh
```

Parse the output and store these values for later use:
- `OWNER`, `REPO` - the current repository (may be a fork)
- `UPSTREAM_OWNER`, `UPSTREAM_REPO` - the target repository for PRs
- `UPSTREAM_REMOTE` - git remote name for upstream ("upstream" for forks, "origin" otherwise)
- `IS_FORK` - whether this is a fork

### 2a. Check PR Exists
If no PR is found (`PR_NUMBER` is "none"):
- Inform the user that no open PR was found for the current branch
- Suggest using `/create-pr` instead
- Stop

Store the PR number, current title (`PR_TITLE`), URL (`PR_URL`), and base branch (`PR_BASE`) for later use.

## Step 3: Generate Title and Description

### Step 3a: Gather stats

Run the following command:

```bash
git diff "$UPSTREAM_REMOTE/$PR_BASE...HEAD" --stat
```

Store the output as `DIFF_STATS`.

### Step 3b: Partition files and launch Explore agents

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
1. Run: git diff "$UPSTREAM_REMOTE/$PR_BASE...HEAD" -- <file1> <file2> ...
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

### Step 3c: Invoke `_pr-description-generator`

Use the Task tool with subagent_type=`_pr-description-generator`. Pass:
- `DIFF_STATS`: from Step 3a
- `CHANGE_SUMMARIES`: collected from Step 3b

Parse the agent's output to extract the generated title and description.

**IMPORTANT**: Preserve the original Motivation-Modifications-Result structure of the generated description. Do NOT summarize, shorten, or restructure it. However, if there are factual inaccuracies (e.g., claiming code was added when it already existed, or mischaracterizing what a change does), fix them so the description accurately reflects the actual diff. Minor cleanup (e.g., fixing obvious typos or formatting) is also acceptable.

## Step 4: Compare Titles Semantically

Before proposing a title change, determine if the new title is **semantically different** from the old one.

**IMPORTANT**: Changing the PR title can break email threading for reviewers. Only propose a title change if truly necessary.

**Consider titles the SAME (keep original) if:**
- They describe the same change with different wording
  - e.g., "Add login feature" ≈ "Implement login functionality"
- Only differ in minor formatting or punctuation
- Same core meaning with synonyms
- Both accurately describe the PR's purpose

**Consider titles DIFFERENT (propose change) if:**
- The old title is outdated (PR scope changed significantly)
- The old title is too vague/generic (e.g., "WIP" or "Fix bug")
- The old title is inaccurate or misleading
- The PR has evolved substantially from its original intent

**Decision**: If semantically equivalent, explicitly state you will **keep the original title** to preserve mail threading.

## Step 5: Present Changes for Approval

Display a clear comparison to the user:

```
## Proposed PR Update

**PR**: #<number> - <url>
**Repository**: <UPSTREAM_OWNER/UPSTREAM_REPO> (if fork, mention "from fork OWNER/REPO")

### Title
**Current**: <old title>
**Proposed**: <new title or "(no change - semantically equivalent)">

### Proposed Description

<show new description>
```

Then use `AskUserQuestion` for approval:

```json
{
  "questions": [{
    "question": "Do you want to apply these changes?",
    "header": "Update PR",
    "multiSelect": false,
    "options": [
      {"label": "Approve all (Recommended)", "description": "Update both title and description"},
      {"label": "Description only", "description": "Keep current title, update description only"},
      {"label": "Cancel", "description": "Don't update the PR"}
    ]
  }]
}
```

If user selects "Other" to request edits, apply their changes and ask again. If "Cancel", stop.

## Step 6: Update the PR

After user approval, apply the changes.

**For forks**: Use `--repo` to target the upstream repository:

### If updating both title and body:
```bash
BODY_FILE=$(mktemp -t update-pr-description)
cat << 'BODY_EOF' >| "$BODY_FILE"
<new description content>
BODY_EOF

# For forks: --repo targets the upstream repository where the PR exists
gh pr edit $PR_NUMBER --repo "$UPSTREAM_OWNER/$UPSTREAM_REPO" --title "$NEW_TITLE" --body-file "$BODY_FILE"
ret=$?; /bin/rm -f "$BODY_FILE"; exit $ret
```

### If updating only the body (title unchanged):
```bash
BODY_FILE=$(mktemp -t update-pr-description)
cat << 'BODY_EOF' >| "$BODY_FILE"
<new description content>
BODY_EOF

# For forks: --repo targets the upstream repository where the PR exists
gh pr edit $PR_NUMBER --repo "$UPSTREAM_OWNER/$UPSTREAM_REPO" --body-file "$BODY_FILE"
ret=$?; /bin/rm -f "$BODY_FILE"; exit $ret
```

**For non-forks**: Omit the `--repo` flag (gh will use current repo).

**Note**: Use `--body-file` instead of `--body` to handle multi-line content and special characters properly.

Report success and show the updated PR URL.
