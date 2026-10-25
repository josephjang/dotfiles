---
description: Reviews an open PR and provides code review feedback as a draft
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Task
  - AskUserQuestion
---

# Review PR

You are helping the user review an open pull request. You will analyze the changes, create a draft review with comments, and provide a link for the user to complete the review on GitHub.

## Step 1: Identify PR to Review

Check if a PR number or URL was provided as an argument: `$ARGUMENTS`

If no argument provided, use `AskUserQuestion`:

```json
{
  "questions": [{
    "question": "Which PR would you like to review?",
    "header": "PR",
    "multiSelect": false,
    "options": [
      {"label": "Current branch PR", "description": "Review the PR for the current branch"},
      {"label": "Specify PR number", "description": "Enter a specific PR number to review"}
    ]
  }]
}
```

## Step 2: Gather GitHub Context

Run the GitHub context script:

```bash
~/.claude/scripts/github-context.sh
```

Parse the output and store:
- `GH_HOST` - GitHub hostname (e.g., `github.com`)
- `OWNER`, `REPO` - the current repository (may be a fork)
- `UPSTREAM_OWNER`, `UPSTREAM_REPO` - the target repository for PRs
- `PR_NUMBER`, `PR_BASE`, `PR_TITLE` - PR information (if reviewing current branch PR)

If reviewing a specific PR number provided by the user, use that instead of `PR_NUMBER` from context.

## Step 3: Fetch PR Details and Existing Comments

### 3a. Fetch PR Information

```bash
gh pr view $PR_NUMBER --repo "$UPSTREAM_OWNER/$UPSTREAM_REPO" --json title,body,author,headRefName,baseRefName,additions,deletions,changedFiles,files,commits
```

### 3b. Fetch Full Diff

```bash
gh pr diff $PR_NUMBER --repo "$UPSTREAM_OWNER/$UPSTREAM_REPO"
```

### 3c. Fetch Existing Comments

Fetch all existing review threads and comments to avoid duplicate feedback:

```bash
gh api graphql -f query="$(cat ~/.claude/scripts/fetch-pr-comments.graphql)" \
  -f owner="$UPSTREAM_OWNER" -f repo="$UPSTREAM_REPO" -F pr_number=$PR_NUMBER
```

From the response, extract:
- **Review threads**: Comments on specific lines with `path`, `line`, and comment `body`
- **General comments**: Discussion comments in the PR
- **Review bodies**: Summary comments from previous reviews

Store these for duplicate detection in Step 5.

## Step 4: Explore Codebase Context

Launch an `Explore` agent to understand how the changed files relate to the broader codebase:

```
Use the Task tool with subagent_type="Explore"

Prompt: "For these changed files in a PR, help me understand:
1. What patterns and conventions exist in similar code in this codebase?
2. How do these files integrate with the rest of the system?
3. Are there related files (tests, types, utilities) that might be affected?

Changed files:
<list of file paths from Step 3a>

Focus on understanding existing patterns so I can review whether the PR follows them."
```

The agent will explore the codebase and return insights about:
- Coding conventions and patterns used in similar files
- How the changed code integrates with existing functionality
- Related code that reviewers should be aware of

Use these insights to inform your review in the next step.

## Step 5: Analyze Changes

Read the changed files to understand the context. For each file in the PR:
1. Read the current version of the file using the Read tool
2. Understand the changes in context of the full file
3. Compare against patterns identified in Step 4

Analyze for:
- **Pattern consistency**: Does the code follow patterns identified in Step 4? Flag deviations from established conventions.
- **Code quality issues**: Poor naming, code duplication, overly complex logic
- **Potential bugs**: Null pointer risks, off-by-one errors, race conditions, unhandled errors
- **Security concerns**: Input validation, injection vulnerabilities, exposed secrets
- **Style/convention violations**: Inconsistent formatting, naming conventions
- **Missing tests**: Untested edge cases, missing test coverage for new functionality
- **Documentation gaps**: Missing or outdated comments/docs for public APIs
- **Integration issues**: Based on Step 4 insights, are there concerns about how changes integrate with existing code?

### Duplicate Detection

Before adding a comment, check existing comments from Step 3c:
- Skip if an existing comment on the same file/line addresses the same issue
- Skip if a general comment or review body already mentions the concern
- Only add comments that provide new, unique feedback

## Step 6: Generate Review

Categorize findings by severity:

### Critical
Issues that must be fixed before merging:
- Security vulnerabilities
- Bugs that will cause failures
- Data corruption risks

### Suggestions
Improvements that should be addressed:
- Code quality issues
- Missing error handling
- Performance concerns

### Nitpicks
Minor issues that are optional:
- Style preferences
- Minor readability improvements

For each finding, prepare:
- File path and line number(s)
- Clear description of the issue
- Suggested fix (if applicable)

## Step 7: Create Draft Review

Create a pending (draft) review via GitHub API.

### 7a. Create the Pending Review

Create a draft review by omitting the `event` parameter. Write the request body as JSON to a temp file.

**Important**: Add a review summary comment that appears first in the GitHub review UI. To ensure this:
1. Get the first file (alphabetically) using:
   ```bash
   ~/.claude/scripts/pr-first-changed-file.sh --repo "$UPSTREAM_OWNER/$UPSTREAM_REPO" --pr $PR_NUMBER
   ```
2. Find the first changed line number in that file from the diff
3. Place the summary comment on that file/line as the **first entry** in the comments array

The line must be part of the diff (added or modified), otherwise the API returns a 422 error. This lets the user copy the summary to the "Finish your review" dialog and delete the comment before submitting.

**Writing a good summary**:
- Brief thanks for quality contributions (1 sentence max)
- Focus on what needs to change, not what the PR does (the author already knows)
- Don't restate the PR description or explain the implementation back to the author
- If no issues found, keep it short: "Thanks, looks good!"

Good examples:
> Thanks for the clean implementation! One minor suggestion about test file organization.

> Thanks for tackling this! A few things need to be addressed before we can merge - see inline comments.

> This needs some rework. The current approach has a security issue with input validation, and the error handling needs to be more robust. Happy to discuss if you have questions.

Bad example (too verbose):
> Overall this is a clean, well-structured PR that adds the About section with proper i18n support and comprehensive tests. The implementation follows existing patterns in the settings page, security attributes on the external link are correct, and the testing infrastructure is properly set up. One minor nitpick about the test file organization.

```bash
REQUEST_FILE=$(mktemp -t review-pr)
cat << 'REQUEST_EOF' >| "$REQUEST_FILE"
{
  "comments": [
    {
      "path": "<first file in diff>",
      "line": "<first changed line number in that file>",
      "body": "**Review Summary** (copy to review dialog, then delete this comment)\n\n<brief thanks + key concerns>"
    },
    {
      "path": "src/file.ts",
      "line": 42,
      "body": "Comment text here"
    }
  ]
}
REQUEST_EOF

gh api "repos/$UPSTREAM_OWNER/$UPSTREAM_REPO/pulls/$PR_NUMBER/reviews" \
  --input "$REQUEST_FILE"
ret=$?; /bin/rm -f "$REQUEST_FILE"; exit $ret
```

For multi-line comments, add `start_line` along with `line` for the range.

### 7b. Provide Review Link

After creating the draft, provide the URL to the PR changes page:

```
## Draft Review Created

**PR**: #<number> - <title>
**Draft comments**: <count> inline comments

Complete your review on GitHub:
https://<GH_HOST>/<UPSTREAM_OWNER>/<UPSTREAM_REPO>/pull/<PR_NUMBER>/files

On the GitHub page you can:
- Edit or delete any draft comments
- Add additional comments
- Submit the review as Approve, Request Changes, or Comment
```
