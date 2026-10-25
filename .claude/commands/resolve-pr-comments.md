---
description: Fetches unresolved PR review comments and general PR comments, then creates a resolution plan
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Edit
  - Write
  - Task
  - TaskCreate
  - TaskUpdate
  - TaskList
  - TaskGet
  - AskUserQuestion
---

# Resolve PR Comments

You are helping the user resolve unresolved review comments and general PR comments on their current PR. This includes:
- **Review threads**: Comments on specific lines of code (can be resolved/unresolved)
- **General PR comments**: Discussion comments not tied to specific code lines (may contain change requests)

**Important - Residual Risks**: Pay attention to any residual risks, concerns, or caveats mentioned by reviewers. These may include:
- Edge cases the reviewer is worried about
- Potential performance implications
- Security considerations
- Backward compatibility concerns
- Future maintenance burden

Even if a comment doesn't explicitly request a change, if it raises a valid risk, either:
1. Address the risk in code (add handling, tests, documentation)
2. Acknowledge the risk in your reply with justification for why it's acceptable
3. Flag it to the user for decision if the risk/tradeoff is significant

## Step 1: Check Working Copy First

Before gathering any other context, check if the working copy is clean:

```bash
git status --porcelain
```

If there are uncommitted changes (output is not empty):
1. Show the list of uncommitted files
2. Inform the user: "Please commit or stash your changes before resolving PR comments."
3. Stop

## Step 2: Gather GitHub Context

Run the GitHub context script:

```bash
~/.claude/scripts/github-context.sh
```

Parse the output and store these values for later use:
- `GH_HOST` - GitHub hostname
- `OWNER`, `REPO` - the current repository (may be a fork)
- `UPSTREAM_OWNER`, `UPSTREAM_REPO` - the target repository for PRs (use these for API calls)
- `UPSTREAM_REMOTE` - git remote name for upstream ("upstream" for forks, "origin" otherwise)
- `IS_FORK` - whether this is a fork
- `PR_NUMBER`, `PR_BASE`, `PR_TITLE` - PR information

### 2a. Check PR Exists
If no PR is found (`PR_NUMBER` is "none"):
- Inform the user that no open PR was found for the current branch
- Stop

## Step 3: Fetch All Comments

Fetch all comment types in a single GraphQL query.

**Important**: Use `UPSTREAM_OWNER` and `UPSTREAM_REPO` since the PR exists in the upstream repository.

Execute the query using the external GraphQL file:

```bash
gh api graphql -f query="$(cat ~/.claude/scripts/fetch-pr-comments.graphql)" \
  -f owner="$UPSTREAM_OWNER" -f repo="$UPSTREAM_REPO" -F pr_number=$PR_NUMBER
```

### 3a. Extract Unresolved Review Threads

From the response, extract review threads where `isResolved == false`:

```jq
.data.repository.pullRequest.reviewThreads.nodes
| map(select(.isResolved == false))
| map({
    id: .id,
    path: .path,
    line: .line,
    startLine: .startLine,
    isOutdated: .isOutdated,
    comments: .comments.nodes
  })
```

**Filtering options**:
1. **Include outdated** (default): Analyze all unresolved comments
2. **Skip outdated**: Add `| map(select(.isOutdated == false))`

### 3b. Extract General PR Comments

From the response, extract issue comments:

```jq
.data.repository.pullRequest.comments.nodes
| map({
    id: .id,
    type: "issue_comment",
    body: .body,
    author: .author.login,
    createdAt: .createdAt,
    url: .url
  })
```

### 3c. Extract Review Bodies

From the response, extract reviews with non-empty bodies:

```jq
.data.repository.pullRequest.reviews.nodes
| map(select(.body != null and .body != ""))
| map({
    id: .id,
    type: "review_body",
    body: .body,
    author: .author.login,
    state: .state,
    createdAt: .submittedAt,
    url: .url
  })
```

**Note**: Reviews with `state: "CHANGES_REQUESTED"` are high priority.

### 3d. Evaluate Comments

Combine general comments (3b) and review bodies (3c) into a single array.

If there are no unresolved review threads AND no general comments, inform the user and stop.

When presenting findings later, clearly distinguish between:
- **Review threads**: Have file/line context, can be marked resolved
- **General comments**: No file context, review manually for action items
- **Review bodies**: Summary of a review submission, check `state` for context

## Step 4: Group Related Threads

Launch the `_pr-thread-grouper` agent to analyze and group semantically related threads:

```
Use the Task tool with subagent_type="_pr-thread-grouper"
Pass:
- Unresolved review threads from Step 3a (array with id, path, line, startLine, isOutdated, comments)
- General PR comments from Step 3b (array with id, type, body, author, createdAt, url, and optionally state for review bodies)
```

The agent will:
- Read all affected files in parallel
- Analyze relationships between threads based on code context and comment content
- Scan general PR comments for actionable change requests
- Return structured groups with relationship rationale

**Note on general comments**: These don't have file/line context, so they may form their own group or be associated with review threads if they discuss related topics.

## Step 5: Analyze Comment Groups in Parallel

Launch analyzers for **semantically related groups** (from Step 4), not individual threads:

**IMPORTANT**: Launch multiple `pr-comment-analyzer` agents simultaneously using a single message with multiple Task tool calls.

For each semantic group:
```
Use the Task tool with subagent_type="_pr-comment-analyzer"
Pass all threads in the group together:
- All file paths involved
- All comment threads in the group (with line numbers, replies, outdated status)
- The identified relationship: "These threads are related because: <reason>"
```

**Parallelization rules**:
- Launch up to 5 analyzer agents in parallel (one per group)
- If more than 5 groups, process in batches of 5
- Each agent handles ALL threads in its assigned group

The analyzer will:
- Read all relevant files for the group
- Understand cross-file relationships
- Analyze each thread with full context of related threads
- Identify if fixing one thread affects others in the group
- Return combined analysis noting inter-thread dependencies

## Step 6: Create Resolution Plan with Agent

After all groups are analyzed, launch the `pr-comment-planner` agent:

```
Use the Task tool with subagent_type="_pr-comment-planner" to create a resolution plan.
Pass all the group analysis results from Step 5.
```

The planner will:
- Validate the pre-formed groups (split if too large, merge if cross-group dependencies found)
- Prioritize groups: blocking → cascading changes → isolated fixes → nitpicks
- Order implementation accounting for dependencies between groups
- Output a structured resolution plan with one commit per group

## Step 7: Present Plan, Create Task List, and Implement Resolutions

Present the resolution plan to the user with:
1. Summary of unresolved comments found
2. Categorized list with priorities
3. Proposed implementation order
4. Estimated changes per file

If this is a fork, mention: "PR is in upstream repository `UPSTREAM_OWNER/UPSTREAM_REPO`"

Then use `AskUserQuestion` for approval:

```json
{
  "questions": [{
    "question": "Do you want to proceed with this resolution plan?",
    "header": "Approve plan",
    "multiSelect": false,
    "options": [
      {"label": "Proceed (Recommended)", "description": "Implement the resolution plan as proposed"},
      {"label": "Cancel", "description": "Don't make any changes"}
    ]
  }]
}
```

If user selects "Other" to request modifications, adjust the plan accordingly and ask again. If "Cancel", stop.

### 7a. Create Task List

After approval, create a task list to track progress. Use `TaskCreate` to create tasks:

1. **One task per resolution group**:
   - Subject: `Group N: <descriptive name>` (e.g., "Group 1: Fix null checks in auth module")
   - Description: List the files affected and comments addressed
   - ActiveForm: `Resolving <group name>` (e.g., "Resolving null checks in auth module")

2. **Post-implementation tasks**:
   - Task: "Generate and approve replies" (activeForm: "Generating replies")
   - Task: "Push commits and post replies" (activeForm: "Pushing commits and posting replies")
   - Task: "Offer PR description update" (activeForm: "Offering PR description update")

Example task creation:
```
TaskCreate:
  subject: "Group 1: Fix null checks in auth module"
  description: "Files: src/auth.ts, src/utils.ts. Comments: guard clause at line 42, null check at line 15"
  activeForm: "Resolving null checks in auth module"
```

### 7b. Implement Resolutions

For each group, in the planned order:
1. Use `TaskUpdate` to set the group's task to `in_progress`
2. Make the code changes
3. Create a commit for the group
4. Track what was changed for each thread (for reply generation)
5. Use `TaskUpdate` to set the group's task to `completed`

**Do NOT push yet** - wait for user approval of replies

### 7c. Validate Changes and Generate Replies IN PARALLEL

After all resolutions are implemented, launch these two operations **in parallel** using a single message with multiple Task tool calls:

**Task 1: Code Validation**
```
Use the Task tool with subagent_type="_code-validator"
No additional input needed - it will detect project type and run checks
```

**Task 2: Generate Replies**

Use `TaskUpdate` to set the "Generate and approve replies" task to `in_progress`.

For each resolved thread, generate a natural, conversational reply:

1. Write in a human-like tone (e.g., "Done!", "Fixed!", "Good catch!")
2. Briefly describe what was changed (1-3 sentences max)
3. If the approach differs from the suggestion, explain why in the same conversational tone
4. **Address any residual risks** mentioned by the reviewer:
   - If the risk was mitigated, explain how (e.g., "Added validation to handle the edge case you mentioned")
   - If the risk is accepted, briefly justify why (e.g., "The performance impact is negligible for our expected data sizes")
   - If additional safeguards were added (tests, docs, error handling), mention them
5. End with:
   ```
   🤖 Generated with Claude Code
   ```

**No headers** - keep the reply flowing naturally.

Wait for BOTH tasks to complete before Step 8.

## Step 8: Present Validation Results and Replies for Approval

### 8a. Present Validation Results

If the code validator found issues, present them first:

```
## Validation Results

❌ **<N> issue(s) found** - please review before pushing:

### <Check Name> Failures
<error details>
```

Then use `AskUserQuestion`:

```json
{
  "questions": [{
    "question": "Validation found issues. How would you like to proceed?",
    "header": "Validation",
    "multiSelect": false,
    "options": [
      {"label": "Fix issues (Recommended)", "description": "Address the validation errors before proceeding"},
      {"label": "Proceed anyway", "description": "Continue despite validation failures"}
    ]
  }]
}
```

If user selects "Other", they can provide specific instructions on what to fix or skip.

If validation passed, briefly note it:
```
## Validation Results
✅ All checks passed
```

### 8b. Present Replies

Present all generated replies to the user, grouped by type:

```
## Generated Replies

### Review Threads (will be added to existing thread)

#### Thread 1: `src/auth.ts:42`
Original comment: "Consider using a guard clause here"

**Proposed reply:**
> Done! Refactored the function to use early return for the null check.
>
> 🤖 Generated with Claude Code

#### Thread 2: `src/utils.ts:15`
...

### Issue Comments (will create new comment with reference)

#### Comment by @reviewer1
Original: "Have you considered adding tests for edge cases?"

**Proposed reply:**
> Re: @reviewer1's comment:
>
> Good point! Added unit tests covering null inputs and boundary conditions.
>
> 🤖 Generated with Claude Code

### Review Bodies (will create new comment with reference)

#### Review by @reviewer2 (CHANGES_REQUESTED)
Original: "Overall looks good but please address the error handling concerns."

**Proposed reply:**
> Re: @reviewer2's review:
>
> Addressed! Added try-catch blocks and proper error propagation as suggested.
>
> 🤖 Generated with Claude Code
```

Use `AskUserQuestion` for reply approval:

```json
{
  "questions": [{
    "question": "How would you like to handle these replies?",
    "header": "Replies",
    "multiSelect": false,
    "options": [
      {"label": "Approve all (Recommended)", "description": "Post all replies as shown"},
      {"label": "Skip replies", "description": "Don't post any replies"}
    ]
  }]
}
```

If user selects "Other", they can specify which replies to edit and how (e.g., "Change thread 2 reply to just say 'Fixed!'"). After user approves (or skips), use `TaskUpdate` to set the "Generate and approve replies" task to `completed`.

## Step 9: Push Commits

Use `TaskUpdate` to set the "Push commits and post replies" task to `in_progress`.

After user approves:
```bash
git push origin HEAD
```

## Step 10: Post Replies

Different comment types require different reply methods:

| Comment Type | Source | Reply Method |
|--------------|--------|--------------|
| Review thread | `reviewThreads` (GraphQL) | GraphQL mutation (adds to thread) |
| Issue comment | `comments` (GraphQL), type=`issue_comment` | New issue comment (reference original) |
| Review body | `reviews` (GraphQL), type=`review_body` | New issue comment (reference original) |

### 10a. Reply to Review Threads

For each approved reply to a review thread, post using GraphQL. This adds the reply directly to the thread:

```bash
gh api graphql \
  -f query="$(cat ~/.claude/scripts/add-review-reply.graphql)" \
  -F threadId="$THREAD_ID" \
  -F body="$REPLY_BODY"
```

### 10b. Reply to Issue Comments

For replies to general issue comments (type=`issue_comment`), create a new comment that references the original:

```bash
# Format the reply to reference the original comment
FORMATTED_REPLY="Re: @$ORIGINAL_AUTHOR's [comment]($ORIGINAL_COMMENT_URL):

$REPLY_BODY"

gh api "repos/$UPSTREAM_OWNER/$UPSTREAM_REPO/issues/$PR_NUMBER/comments" \
  -f body="$FORMATTED_REPLY"
```

### 10c. Reply to Review Bodies

For replies to review bodies (type=`review_body`), create a new comment that references the original review:

```bash
# Format the reply to reference the original review
FORMATTED_REPLY="Re: @$ORIGINAL_AUTHOR's [review]($ORIGINAL_REVIEW_URL):

$REPLY_BODY"

gh api "repos/$UPSTREAM_OWNER/$UPSTREAM_REPO/issues/$PR_NUMBER/comments" \
  -f body="$FORMATTED_REPLY"
```

**Note**: GitHub doesn't support threaded replies to issue comments or review bodies, so we create new comments with references to the original for context.

Report success/failure for each posted reply.

After all replies are posted, use `TaskUpdate` to set the "Push commits and post replies" task to `completed`.

## Step 11: Offer to Update PR Description

Use `TaskUpdate` to set the "Offer PR description update" task to `in_progress`.

After all comments are resolved and replies posted, the PR may have changed significantly. Use `AskUserQuestion`:

```json
{
  "questions": [{
    "question": "The PR may have changed significantly. Would you like to update the PR description?",
    "header": "Update PR",
    "multiSelect": false,
    "options": [
      {"label": "Yes, update (Recommended)", "description": "Regenerate title and description to reflect all changes"},
      {"label": "No, keep current", "description": "Keep the existing PR title and description"}
    ]
  }]
}
```

### If user chooses to update:

1. **Gather stats**:
   ```bash
   git diff "$UPSTREAM_REMOTE/$PR_BASE...HEAD" --stat
   ```
   Store the output as `DIFF_STATS`.

2. **Partition files and launch Explore agents** - parse the `--stat` output, group files by directory, and launch Explore agents in parallel (subagent_type=`Explore`). Use the same partitioning strategy and prompt template as described in the `/create-pr` command Step 4b. Substitute `$UPSTREAM_REMOTE/$PR_BASE` for the diff range. Collect outputs as `CHANGE_SUMMARIES`.

3. **Invoke `_pr-description-generator`** - use the Task tool with subagent_type=`_pr-description-generator`, passing `DIFF_STATS` and `CHANGE_SUMMARIES`.

4. Parse the generated title and description
5. Compare titles semantically (same logic as update-pr-description command):
   - If semantically equivalent, keep original title to preserve email threading
   - If significantly different, propose the new title
6. Present the proposed changes:
   ```
   ## Proposed PR Update

   **PR**: #<number>
   **Repository**: <UPSTREAM_OWNER/UPSTREAM_REPO> (if fork, mention "from fork OWNER/REPO")

   ### Title
   **Current**: <old title>
   **Proposed**: <new title or "(no change - semantically equivalent)">

   ### Proposed Description

   <show new description>
   ```

   Then use `AskUserQuestion`:

   ```json
   {
     "questions": [{
       "question": "Do you want to apply these changes?",
       "header": "Confirm",
       "multiSelect": false,
       "options": [
         {"label": "Approve all (Recommended)", "description": "Update both title and description"},
         {"label": "Description only", "description": "Keep current title, update description only"},
         {"label": "Cancel", "description": "Don't update the PR"}
       ]
     }]
   }
   ```

   If user selects "Other", they can request specific edits to the title or description.
7. After user approval, update via:

   **For forks**: Use `--repo` to target the upstream repository:
   ```bash
   BODY_FILE=$(mktemp -t update-pr-description)
   cat << 'BODY_EOF' >| "$BODY_FILE"
   <new description content>
   BODY_EOF

   # For forks: --repo targets the upstream repository where the PR exists
   gh pr edit $PR_NUMBER --repo "$UPSTREAM_OWNER/$UPSTREAM_REPO" --title "$NEW_TITLE" --body-file "$BODY_FILE"
   # Or without --title if keeping original
   ret=$?; /bin/rm -f "$BODY_FILE"; exit $ret
   ```

   **For non-forks**: Omit the `--repo` flag.

Use `TaskUpdate` to set the "Offer PR description update" task to `completed`.

Use `TaskList` to show the final status of all tasks to the user.
