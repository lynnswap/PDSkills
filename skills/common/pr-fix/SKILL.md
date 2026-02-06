---
name: pr-fix
description: Address PR review comments efficiently. Auto-detects PR from current branch, fetches unresolved threads, applies fixes, and posts threaded replies. Use when responding to review feedback.
---

# PR Fix

## Overview

Streamline the workflow for addressing PR review comments. This skill:
- Auto-detects the PR from the current branch (or accepts PR number/URL as argument)
- Fetches all unresolved review threads (review comment threads)
- Guides through fixing each issue
- Posts reply comments properly threaded to the original review comment

## Workflow

1. **Identify the PR**
   - If the user provides a PR number or URL, use it.
   - Otherwise, detect from the current branch:
     - Get the current branch: `git rev-parse --abbrev-ref HEAD`
     - Determine `owner` and `repo` from `git remote get-url origin`
     - Use GitHub MCP `list_pull_requests` with:
       - `owner`: `<owner>`
       - `repo`: `<repo>`
       - `state`: `open`
       - `head`: `<owner>:<branch>` (if the branch lives on a fork, use `<fork_owner>:<branch>`)
     - If multiple PRs match, choose the one whose head ref matches exactly; otherwise ask the user.
   - If no PR is found, ask the user to specify one.

2. **Fetch unresolved review threads**
   - Use GitHub MCP `pull_request_read` with `method: "get_review_comments"`.
   - Paginate with `after` and `perPage` until `pageInfo.hasNextPage` is false:
     - Use the response `pageInfo.endCursor` as the next request's `after`.
   - Filter to only unresolved threads (`IsResolved: false`).
   - Extract priority badges (P1/P2/P3) from comment body if present.
   - For each thread, record:
     - `threadId`: thread `ID`
     - `commentId`: extract from the first comment `URL` (parse digits from `discussion_r<id>`)
     - `path` and `line`: from the first comment `Path` / `Line`
   - Never rely on `path+line` for identity; line numbers drift after edits. Prefer `commentId` (derived from URL).

3. **Display unresolved threads**
   - Show a numbered list with:
     - File path and line number
     - Priority badge (if any)
     - `commentId` (reply target)
     - First 2-3 lines of the comment body
     - Author
   - If no unresolved threads, report success and exit.

4. **Proceed with all threads by default**
   - Do **not** ask which threads to handle.
   - Address all unresolved threads sequentially.
   - Only if the user explicitly requests it, switch to:
     - Select specific threads by number
     - Dry run (show what would be done without executing)

5. **For each thread**:
   a. **Show full context**
      - Display the complete comment
      - Read the relevant file and show surrounding code

   b. **Implement the fix**
      - Apply code changes as needed
      - If no code change is needed (acknowledgment only), note this

   c. **Post reply comment**
      - Use GitHub MCP `add_reply_to_pull_request_comment` to reply to the original review comment:
        - `owner`: `<owner>`
        - `repo`: `<repo>`
        - `pullNumber`: `<PR_NUMBER>`
        - `commentId`: `<commentId>` (numeric; extracted from `discussion_r...`)
        - `body`: `<reply message>`
      - Reply templates:
        - Code fix: "Fixed: <brief description of what was changed>"
        - Acknowledgment: "Acknowledged. <brief response>"
        - Won't fix: "Won't fix: <reason>"

   d. **(Optional) Resolve the thread**
      - `github-mcp-server` currently does not expose a tool to resolve review threads.
      - If the user wants threads resolved, do it in the GitHub web UI after replies are posted.

   e. **Move to next thread**

6. **Report completion**
   - Number of threads addressed
   - Number of threads remaining (if any)
   - Suggest next steps:
     - Commit changes if there are uncommitted modifications
     - Push and request re-review if appropriate

## Dry Run Mode

When dry run is explicitly requested:
- List all unresolved threads with full details
- For each thread, describe what action would be taken
- Do NOT make any API calls to post replies
- Do NOT modify any files

## Reply Comment Guidelines

- Keep replies concise (1-2 sentences)
- Focus on what was done, not why the reviewer was right
- For code changes: reference the specific fix (e.g., "Added null check before accessing property")
- For acknowledgments: be brief (e.g., "Good catch, updated.")
- For won't fix: explain the reasoning clearly

## Edge Cases

- **Comment requires no code change**: Post acknowledgment reply (and optionally resolve via UI)
- **New reviews added during session**: Re-fetch threads before processing next item
- **API rate limiting**: Pause and retry with backoff
- **Thread already resolved**: Skip and move to next
- **Multiple comments in thread**: Reply to the first (top-level) comment only
- **Line numbers drifted**: Match by `commentId` (derived from the comment URL) or comment URL, not by `path+line`.

## Integration with Other Skills

After completing all fixes:
- If there are uncommitted changes, suggest using `/ship` or manual commit
- If user wants re-review, suggest commenting `@codex review` on the PR (use GitHub MCP `add_issue_comment`)

## Error Handling

- If GitHub MCP tools are unavailable, ask the user to enable the GitHub MCP server and retry
- If PR detection is ambiguous, ask the user for the PR URL/number
- If fetching review threads fails, show the error and suggest using the PR URL as fallback context
- If reply fails, show the error and continue with the next thread

## Examples

### Basic usage (auto-detect PR)
```
/pr-fix
```

### Specify PR by number
```
/pr-fix 38
```

### Specify PR by URL
```
/pr-fix https://github.com/owner/repo/pull/38
```

### Dry run
```
/pr-fix --dry-run
```
