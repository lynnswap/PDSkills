---
name: ask-codex
description: Send a plan, in-progress changes, or any context to Codex for review. Iterates until approved or max 10 rounds. Use when Claude is working and needs cross-review from Codex, or when the user explicitly calls /ask-codex.
---

# Ask Codex

## Overview

Send a plan, in-progress changes, or custom context to Codex for review. Iterate on feedback until Codex approves (responds with "LGTM") or until 10 rounds are reached.

## Review Modes

| Mode | When to use | Input source |
|------|-------------|--------------|
| Plan review | Before execution | Plan file (`plan-*.md`) or text |
| Change review | During implementation | `git diff` + untracked files |
| Custom | Any time | User-specified context |

## Workflow

1. **Determine the review mode**
   - If the user specifies a mode, use it.
   - If auto-invoked on plan mode exit and a plan file matching `~/.claude/plans/plan-*.md` exists, default to **plan review** (even if there are uncommitted changes).
   - If there are uncommitted changes (`git status --porcelain` is non-empty), default to **change review**.
   - Otherwise, ask the user what to review.

2. **Collect the review content**
   - **Plan review**: Read from `~/.claude/plans/plan-*.md` (use the most recently modified if multiple exist) or ask the user for the plan.
   - **Change review**: Collect both tracked and untracked changes:
     ```sh
     # Tracked changes (staged + unstaged)
     # Use fallback for repos without commits
     if git rev-parse --verify HEAD >/dev/null 2>&1; then
       git diff HEAD
     else
       git diff --cached
       git diff
     fi

     # Untracked files - safe handling for special characters
     # Skip binary files and files larger than 100KB
     git ls-files -z --others --exclude-standard | while IFS= read -r -d '' f; do
       # Skip binary files (use -- to handle filenames starting with -)
       if file -- "$f" | grep -q 'text'; then
         # Skip files larger than 100KB
         size=$(stat -f%z -- "$f" 2>/dev/null || stat -c%s -- "$f" 2>/dev/null)
         if [ "$size" -lt 102400 ]; then
           echo "=== New file: $f ==="
           cat -- "$f"
         else
           echo "=== New file: $f (skipped: >100KB) ==="
         fi
       else
         echo "=== New file: $f (skipped: binary) ==="
       fi
     done
     ```
   - **Custom**: Ask the user to provide the content.
   - Also collect the original user prompt (task background) from the conversation.

3. **Prepare the plans directory**
   - Run `mkdir -p ~/.claude/plans` to ensure the directory exists.

4. **Write the review input file**
   - Create a file at `~/.claude/plans/review-input.md` with this format:
     ```
     ## Original Request
     <original user prompt>

     ## Review Mode
     <plan review | change review | custom>

     ## Content to Review
     <plan, diff + untracked files, or custom content>

     ## Review Task
     Review the above content.
     - If there are problems, describe them specifically.
     - If there are no problems, respond with only "LGTM".
     ```

5. **Set up the temp environment**
   - Prepare a temp directory under `~/.codex/tmp` (same as codex-review):
     ```sh
     mkdir -p ~/.codex/tmp
     TMPDIR="$(mktemp -d ~/.codex/tmp/ask-codex.XXXXXXXX)"
     ZDOTDIR="$TMPDIR/zsh"
     mkdir -p "$ZDOTDIR"
     XCRUN_CACHE_PATH="$TMPDIR/xcrun_db"
     DARWIN_USER_TEMP_DIR="$TMPDIR"
     export TMPDIR ZDOTDIR XCRUN_CACHE_PATH DARWIN_USER_TEMP_DIR
     ```

6. **Run Codex**
   - Execute: `cat ~/.claude/plans/review-input.md | codex exec --sandbox read-only -`
   - Timeout: 5 minutes (300 seconds).

7. **Parse the result**
   - Trim whitespace from the output.
   - Check if any line exactly matches "LGTM" (case-insensitive).
   - If matched, mark as **approved**.
   - Otherwise, extract the feedback as **issues found**.

8. **Feedback loop**
   - If issues are found:
     - Report the feedback to the user.
     - For **change review**: Apply fixes to the code, then re-collect the diff and untracked files.
     - For **plan review**: Adjust the plan based on feedback.
     - Return to step 4 and resubmit.
   - Maximum 10 iterations.

9. **Finish**
   - **Approved**: Report "Codex review approved" and proceed to execution automatically.
   - **Not approved after 10 rounds**: Report remaining issues and stop. Ask the user how to proceed.

## Auto-invocation

This skill is automatically invoked when:
- Claude Code exits plan mode (cross-review before execution).
- Claude Code completes any task with code changes (cross-review before proceeding).
- The user has not explicitly skipped cross-review.

Note: For ad-hoc reviews at any point during implementation, use `/ask-codex` manually.

## Notes

- Use `--sandbox read-only` since review does not require code modifications by Codex.
- Honor explicit user requests to skip the review.
- Plan files use the naming convention `plan-*.md` to distinguish from `review-input.md`.
- The review input file at `~/.claude/plans/review-input.md` persists for debugging and history.
- For change review, both `git diff` and untracked file contents are collected to ensure complete coverage.
- LGTM detection uses exact line match (after trimming) to avoid false positives like "Not LGTM".
- Binary files and files larger than 100KB are skipped to avoid input bloat.
