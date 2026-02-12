---
name: codex-review
description: Self-review loop for code changes. Use when Codex edits files or prepares a PR and should run `codex review`, fix findings, and re-run until clean (max 10).
---

# Codex Review

## Overview
Run a local self-review loop after code changes. Choose the correct review mode (`--uncommitted`, `--base`, or `--commit`), and iterate until clean.

By default, run reviews in **quiet mode** so only the final review comments are surfaced (avoid streaming transcript logs into the chat context).

## Output policy (quiet by default)
- Do not paste or stream `codex` transcript logs into the chat (MCP startup, `thinking`, `exec`, tool output, diffs, warnings, etc.).
- Redirect stdout/stderr to a log file for long-running commands.
- For the review step, use the skill-local wrapper script `scripts/codex-review-quiet.sh` (prints only the final review message; writes full transcript to a temp log). Do not run `codex review` directly. Invoke it via this skill directory (not the repo under review).
- Only open/inspect the log file when a command fails. Keep any excerpts minimal (prefer `rg`/`tail` on the log instead of dumping the whole file).

## `codex-review-quiet.sh` contract
- Location: `scripts/codex-review-quiet.sh` (run it from this skill directory, not from the repo under review).
- Purpose: run `codex review` in a way that prints only the final review comments, while keeping full transcript logs out of the chat context.
- Wrapper-only args: `-C <DIR>` / `--cd <DIR>`: `cd` to the repo root before running `codex`.
- Forwarded args: everything else is forwarded to `codex review` unchanged (for example `--base ...`, `--uncommitted`, `--commit ...`, plus any `-c ...` you choose to pass).
- Output behavior (while running): stdout/stderr are redirected to a temp log file (so the chat stays quiet).
- Output behavior (success): prints only the final review message, then deletes the temp files.
- Output behavior (failure): prints the last agent message (if available), a short error summary, and the paths to the temp `log` and `events` files, and keeps them for inspection.
- Notes:
  - The wrapper uses `codex exec review --json` and `jq` to extract the final review text from the JSONL event stream.
  - `jq` is required.
- Examples:
```bash
cd <path/to/this-skill-dir>
./scripts/codex-review-quiet.sh -C /path/to/repo --base origin/main
```
```bash
./scripts/codex-review-quiet.sh -C /path/to/repo --uncommitted
```
```bash
./scripts/codex-review-quiet.sh -C /path/to/repo --commit <sha>
```

## Workflow
1. Confirm the repo is a git checkout and changes exist. If `git status --porcelain` is empty, skip the loop.
2. Confirm the working directory is the repo root for the changes under review. If changes live in a nested repo (e.g., `dependencies/<Repo>`), run all commands from that repo root or set `workdir`/`-C` so paths like `Sources/` resolve correctly.
3. Choose the review mode:
   - Use `--uncommitted` to review staged/unstaged/untracked changes (worktree-only).
   - Use `--base <base>` to review committed changes on the current branch against a base branch (see "Base selection").
   - Use `--commit <sha>` to review the changes introduced by a single commit.
4. Run the chosen review command in quiet mode and wait for completion. Depending on repository size and review scope, this can take around 10-20 minutes.
   - Use the skill-local wrapper `scripts/codex-review-quiet.sh` so only the final review message is printed.
   - If the command fails, inspect the log and surface the minimal relevant error.
5. If findings exist, fix them.
6. Repeat steps 4-5 until clean or 10 iterations. Follow "Re-review after fixes" so each re-run includes your latest fixes (especially for `--base` and `--commit`).
7. Stop after 10 iterations and report remaining issues with context.

## Long-running review policy
- Never terminate `codex review` based only on elapsed time.
- Keep waiting until the review process exits.
- In quiet mode there may be intentionally no terminal output; keep waiting without polling/reading the log unless the process fails.
- Do not emit periodic status updates while waiting; just wait.
- Stop only when:
  1. the process exits,
  2. a clear fatal error occurs, or
  3. the user explicitly asks to cancel.

## Base selection
Use the first match in this priority order, then keep it fixed for the loop:
1. Use `CODEX_REVIEW_BASE` if set.
2. If `.codex-review.json` exists at repo root, read `base` or `baseCandidates`.
3. If the current branch has an upstream (`git rev-parse --abbrev-ref --symbolic-full-name @{u}`), use it.
4. If `origin/HEAD` exists, use it.
5. Else collect candidates from: `origin/develop/*`, `origin/develop`, `origin/main`, `origin/master`, `develop`, `main`, `master`. Prefer candidates that are ancestors of `HEAD`.
6. If a single candidate remains, use it. If none or multiple remain, ask the user to choose and explain the options.

## Re-review after fixes
### `--uncommitted`
`--uncommitted` reviews the current worktree. After fixes, re-run the same `--uncommitted` review mode.

### `--base <branch>`
`--base <branch>` reviews committed changes on the current branch against `<branch>`. It does not include new uncommitted fixes you apply while addressing findings.

After applying fixes from a base-branch review, choose one:
- If commits are allowed and desired, commit the fixes and re-run the same `--base <branch>` review mode.
- Otherwise, re-run with `--uncommitted` so the latest worktree state is reviewed.

### `--commit <sha>`
`--commit <sha>` reviews an immutable commit. If you apply fixes in your working tree, re-running `--commit <sha>` will keep reviewing the original commit and will not include the fixes.

After applying fixes from a commit-target review, choose one:
- If commits are allowed and desired, commit the fixes and re-run with `--commit <new_sha>` (or switch to `--base <branch>`).
- Otherwise, re-run with `--uncommitted` so the latest worktree state is reviewed.

Only create commits when the user explicitly requested it or the repository policy allows it. If unsure, ask.

## Notes
- Honor explicit user requests to skip review.
- Ask the user to choose the base when ambiguous; do not guess silently.
- Do not add ad-hoc liveness checks while `codex review` is running (for example, extra status commands) unless there are clear fatal error signals.
