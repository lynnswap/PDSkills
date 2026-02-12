---
name: pr-fix
description: Address PR review comments efficiently. Auto-detects PR from current branch, fetches unresolved threads, applies fixes, posts threaded replies, and resolves threads. Use when responding to review feedback.
---

# PR Fix

## Overview

Streamline the workflow for addressing PR review comments. This skill:
- Auto-detects the PR from the current branch (or accepts PR number/URL as argument)
- Fetches all unresolved review threads (review comment threads)
- Guides through fixing each issue
- Posts reply comments properly threaded to the original review comment
- Resolves threads after replies are posted

## Non-interactive Defaults (Important)

- Run end-to-end without confirmation prompts. Treat invoking `/pr-fix` as permission to:
  - Apply fixes
  - Commit and push changes to the PR branch
  - Reply to review comments and resolve threads
- Only ask the user when blocked (e.g., PR cannot be identified, auth/tools missing, or stash restore conflicts).

## Workflow

1. **Identify the PR**
   - Determine `owner` and `repo` for all subsequent API calls:
     - If the user provides a PR URL, parse `owner` and `repo` from it (e.g. `https://github.com/<owner>/<repo>/pull/<number>`).
     - Otherwise, determine `owner` and `repo` from `git remote get-url origin` (or another selected remote if `origin` is missing).
     - Fork workflow note: if an `upstream` remote exists and points to a different GitHub repo than `origin`, also capture `upstream_owner`/`upstream_repo` from `git remote get-url upstream` (PRs are often opened in the upstream repo).
   - If the user provides a PR URL, parse `pull_number` from it and use the parsed `owner`/`repo`.
   - If the user provides a PR number (without a URL), set `pull_number` and resolve which repo it belongs to:
     - If `upstream_owner`/`upstream_repo` are available, try resolving the PR number against the upstream repo first (preferred):
       - Prefer a lightweight PR metadata fetch (via GitHub MCP if available, otherwise `gh pr view <pull_number> --repo <upstream_owner>/<upstream_repo>`).
       - If it exists, use `<upstream_owner>/<upstream_repo>` for all subsequent API calls (fetch/reply/resolve).
       - Otherwise, fall back to `<owner>/<repo>` (derived from the selected remote).
     - If no upstream remote is available, use `<owner>/<repo>`.
   - Otherwise, detect from the current branch:
     - Get the current branch: `git rev-parse --abbrev-ref HEAD`
     - Use GitHub MCP `list_pull_requests` with:
       - `owner`: `<owner>`
       - `repo`: `<repo>`
       - `state`: `open`
       - `head`: `<owner>:<branch>` (if the branch lives on a fork, use `<fork_owner>:<branch>`)
     - If multiple PRs match, choose the one whose head ref matches exactly; otherwise ask the user.
     - Fork workflow note: if `upstream_owner`/`upstream_repo` are available, query `list_pull_requests` against the upstream repo first with `head: <fork_owner>:<branch>`, then fall back to querying the `origin` repo.
   - If no PR is found, ask the user to specify one.
   - Ensure you're on the PR head branch locally before editing:
     - Prefer: `gh pr checkout <pull_number>`
   - Keep commits clean without prompting:
     - If the working tree is dirty, auto-stash before making fixes:
       - `git stash push -u -m "pr-fix: auto-stash before applying review fixes"`
     - After all fixes are committed/pushed, restore it:
       - `git stash pop`
       - If restore conflicts, report and stop (do not force-resolve silently).

2. **Fetch unresolved review threads**
   - Use GitHub MCP `pull_request_read` with `method: "get_review_comments"`.
   - Paginate with `after` and `perPage` until `pageInfo.hasNextPage` is false:
     - Use the response `pageInfo.endCursor` as the next request's `after`.
   - This method returns review threads (not a flat list of comments) with metadata like `ID` and `IsResolved`.
   - Filter to only unresolved threads (`IsResolved: false`).
   - Extract priority badges (P1/P2/P3) from the top-level comment body if present.
   - For each thread, record:
     - `threadId`: thread `ID`
     - `commentId`: extract from the top-level comment `URL` (parse digits from `discussion_r<id>`)
     - `path` and `line`: from the top-level comment `Path` / `Line` (or thread-level `Path` / `Line` if that's what the API returns)
   - Never rely on `path+line` for identity; line numbers drift after edits. Prefer `commentId`.

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
   - Do **not** ask for confirmation to commit/push/reply/resolve.
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
      - If code changes were made, commit and push them before replying/resolving:
        - Stage the intended changes (after auto-stash, `git add -A` is typically fine)
        - Commit with a concise, diff-based message
        - Push to the PR branch (e.g., `git push`, or `git push -u origin HEAD` if needed)

   c. **Post reply comment**
      - Prefer GitHub MCP if your toolset exposes a tool to reply to a pull request review comment.
      - Otherwise, use `gh` to reply to the top-level review comment (`commentId`):
        ```sh
        gh api repos/{owner}/{repo}/pulls/{pull_number}/comments/{comment_id}/replies \
          -f body="<reply message>"
        ```
      - Reply templates:
        - Code fix: "Fixed: <brief description of what was changed>"
        - Acknowledgment: "Acknowledged. <brief response>"
        - Won't fix: "Won't fix: <reason>"

   d. **Resolve the thread**
      - Resolve after posting the reply (do not resolve threads you did not respond to).
      - Prefer GitHub MCP if your toolset exposes a tool to resolve review threads.
      - Otherwise, use `gh` and the thread `threadId`:
        ```sh
        gh api graphql -f query='
          mutation($threadId: ID!) {
            resolveReviewThread(input: {threadId: $threadId}) {
              thread { isResolved }
            }
          }
        ' -f threadId="$THREAD_ID"
        ```
      - If resolve fails (permissions, thread already resolved/outdated), report it and continue.

   e. **Move to next thread**

6. **Report completion**
   - Number of threads addressed
   - Number of threads remaining (if any)
   - Mention whether fixes were committed and pushed
   - Mention whether an auto-stash was restored (or why it was not)

## Dry Run Mode

When dry run is explicitly requested:
- List all unresolved threads with full details
- For each thread, describe what action would be taken
- Do NOT make any API calls to post replies or resolve threads
- Do NOT modify any files

## Reply Comment Guidelines

- Keep replies concise (1-2 sentences)
- Focus on what was done, not why the reviewer was right
- For code changes: reference the specific fix (e.g., "Added null check before accessing property")
- For acknowledgments: be brief (e.g., "Good catch, updated.")
- For won't fix: explain the reasoning clearly

## Edge Cases

- **Comment requires no code change**: Post acknowledgment reply and resolve
- **New reviews added during session**: Re-fetch threads before processing next item
- **API rate limiting**: Pause and retry with backoff
- **Thread already resolved**: Skip and move to next (only if `IsResolved` is available)
- **Multiple comments in thread**: Reply to the first (top-level) comment only
- **Line numbers drifted**: Match by `commentId` (derived from the comment URL) or comment URL, not by `path+line`.

## Error Handling

- If GitHub MCP tools are unavailable, ask the user to enable the GitHub MCP server and retry
- If PR detection is ambiguous, ask the user for the PR URL/number
- If fetching review threads fails, show the error and suggest using the PR URL as fallback context
- If reply fails, show the error and continue with the next thread
- If `gh` is required but unavailable or unauthenticated, ask the user to install/login (or fall back to replying/resolving in the GitHub web UI)

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
