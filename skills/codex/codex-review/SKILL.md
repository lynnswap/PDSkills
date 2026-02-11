---
name: codex-review
description: Self-review loop for code changes. Use when Codex edits files or prepares a PR and should run `codex exec review --json`, extract only the final `agent_message`, fix findings, and re-run until clean (max 10). Also run tests when a test command is configured or detectable.
---

# Codex Review

## Overview
Run tests first when possible, then run a local self-review loop with `codex exec review --json` after code changes, extract only the final `agent_message` from JSON events, choose the correct review mode (`--uncommitted`, `--base`, or `--commit`), and re-run tests if review fixes changed code.

## Workflow
1. Confirm the repo is a git checkout and changes exist. If `git status --porcelain` is empty, skip the loop.
2. Confirm the working directory is the repo root for the changes under review. If changes live in a nested repo (e.g., `dependencies/<Repo>`), run all commands from that repo root or set `workdir`/`-C` so paths like `Sources/` resolve correctly.
3. Resolve the test command (see "Test selection") and run tests now. If tests fail, fix and repeat step 3. If no test command is found, continue.
4. Prepare the temp environment under `~/.codex/tmp` (see "Temp directory setup"). Ensure these env vars are set in the process environment that launches `codex ... review` (a wrapper script is fine as long as the vars are exported for the `codex` process).
5. Choose the review mode:
   - Use `--uncommitted` to review staged/unstaged/untracked changes (worktree-only).
   - Use `--base <base>` to review committed changes on the current branch against a base branch (see "Base selection").
   - Use `--commit <sha>` to review the changes introduced by a single commit.
6. If the user wants to override the review model, append `-c review_model="MODEL"` to the review command (default stays as-is when omitted).
7. If the user wants to override reasoning effort, append `-c model_reasoning_effort="EFFORT"` to the review command (default stays as-is when omitted). Use a value supported by the review model.
8. Run the chosen `codex exec review --json` command (plus optional `-c ...` from steps 6-7) with the temp env from step 4, using a 30-minute (1800s) timeout, and extract only `agent_message` output.
   - When piping to `jq`, enable `pipefail` so failures from `codex exec review --json` are not masked by the pipeline.
   - Example:
    `set -o pipefail && codex exec review --json --base <base> [-c review_model="MODEL"] [-c model_reasoning_effort="EFFORT"] | jq -rs 'map(select(.type=="item.completed" and .item.type=="agent_message") | .item.text) | last // empty'`
9. If findings exist, fix them.
10. Repeat steps 8-9 until clean or 10 iterations. Follow "Re-review after fixes" so each re-run includes your latest fixes (especially for `--base` and `--commit`).
11. If any fixes were made after the initial test run, re-run tests (see "Test selection"). If tests fail, fix and return to step 8.
12. Stop after 10 iterations and report remaining issues with context.

## Temp directory setup
Use a per-run temp directory to avoid `/tmp` failures and allow parallel runs. Set these env vars in the process that launches `codex exec review --json`.
Only `~/.codex/tmp` is allowed for temp usage. Do not create temp directories inside the repo (e.g., `.tmp`) or under `/tmp`.
When running with `--sandbox workspace-write`, ensure `ZDOTDIR` is inside `TMPDIR` so the shell does not access paths outside the sandbox.
Avoid `~/.codex/tmp/zsh.*` or other `TMPDIR`-external `ZDOTDIR` paths.

```
mkdir -p ~/.codex/tmp
TMPDIR="$(mktemp -d ~/.codex/tmp/codex-review.XXXXXXXX)"
ZDOTDIR="$TMPDIR/zsh"
mkdir -p "$ZDOTDIR"
XCRUN_CACHE_PATH="$TMPDIR/xcrun_db"
DARWIN_USER_TEMP_DIR="$TMPDIR"
DARWIN_USER_CACHE_DIR="$TMPDIR/cache"
CLANG_MODULE_CACHE_PATH="$TMPDIR/clang-module-cache"
mkdir -p "$DARWIN_USER_CACHE_DIR" "$CLANG_MODULE_CACHE_PATH"
export TMPDIR ZDOTDIR XCRUN_CACHE_PATH DARWIN_USER_TEMP_DIR DARWIN_USER_CACHE_DIR CLANG_MODULE_CACHE_PATH
```

Recommended launch example:

```
mkdir -p ~/.codex/tmp
TMPDIR="$(mktemp -d ~/.codex/tmp/codex-review.XXXXXXXX)"
ZDOTDIR="$TMPDIR/zsh"
mkdir -p "$ZDOTDIR"
XCRUN_CACHE_PATH="$TMPDIR/xcrun_db"
DARWIN_USER_TEMP_DIR="$TMPDIR"
DARWIN_USER_CACHE_DIR="$TMPDIR/cache"
CLANG_MODULE_CACHE_PATH="$TMPDIR/clang-module-cache"
mkdir -p "$DARWIN_USER_CACHE_DIR" "$CLANG_MODULE_CACHE_PATH"
export TMPDIR ZDOTDIR XCRUN_CACHE_PATH DARWIN_USER_TEMP_DIR DARWIN_USER_CACHE_DIR CLANG_MODULE_CACHE_PATH
set -o pipefail
codex exec review --json --base <base> [-c review_model="MODEL"] [-c model_reasoning_effort="EFFORT"] | jq -rs 'map(select(.type=="item.completed" and .item.type=="agent_message") | .item.text) | last // empty'
```

If you cannot set these env vars directly on the `codex exec review --json` process, stop and ask the user.

Keep the temp dir for debugging if needed; otherwise it can be removed after the loop.

## Base selection
Use the first match in this priority order, then keep it fixed for the loop:
1. Use `CODEX_REVIEW_BASE` if set.
2. If `.codex-review.json` exists at repo root, read `base` or `baseCandidates`.
3. If the current branch has an upstream (`git rev-parse --abbrev-ref --symbolic-full-name @{u}`), use it.
4. If `origin/HEAD` exists, use it.
5. Else collect candidates from: `origin/develop/*`, `origin/develop`, `origin/main`, `origin/master`, `develop`, `main`, `master`. Prefer candidates that are ancestors of `HEAD`.
6. If a single candidate remains, use it. If none or multiple remain, ask the user to choose and explain the options.

## Test selection
Use the first match in this priority order:
1. Use `CODEX_TEST_COMMAND` if set.
2. If `.codex-review.json` defines `test`, run it.
3. If `scripts/test.sh` exists, run `./scripts/test.sh`.
4. If `Makefile` has a `test` target, run `make test`.
5. If `package.json` has a `test` script: use `pnpm test` when `pnpm-lock.yaml` exists, otherwise `npm test`.
6. If no test command is found, report "Not run (no test command configured)".

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
- Honor explicit user requests to skip review or tests.
- Ask the user to choose the base when ambiguous; do not guess silently.
