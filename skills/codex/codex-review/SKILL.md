---
name: codex-review
description: Self-review loop for code changes. Use when Codex edits files or prepares a PR and should run `codex review`, fix findings, and re-run until clean (max 10). Also run tests when a test command is configured or detectable.
---

# Codex Review

## Overview
Run tests first when possible, then run a local self-review loop with `codex review` after code changes. Always run `codex review` with `-c model_reasoning_effort="high"`, choose the correct review mode (`--uncommitted`, `--base`, or `--commit`), and re-run tests if review fixes changed code.

## Workflow
1. Confirm the repo is a git checkout and changes exist. If `git status --porcelain` is empty, skip the loop.
2. Confirm the working directory is the repo root for the changes under review. If changes live in a nested repo (e.g., `dependencies/<Repo>`), run all commands from that repo root or set `workdir`/`-C` so paths like `Sources/` resolve correctly.
3. Resolve the test command (see "Test selection") and run tests now. If tests fail, fix and repeat step 3. If no test command is found, continue.
4. Choose the review mode:
   - Use `--uncommitted` to review staged/unstaged/untracked changes (worktree-only).
   - Use `--base <base>` to review committed changes on the current branch against a base branch (see "Base selection").
   - Use `--commit <sha>` to review the changes introduced by a single commit.
5. Run the chosen `codex review` command with `-c model_reasoning_effort="high"` and wait for completion. Depending on repository size and review scope, this can take around 10-20 minutes.
   - If the command fails with an "unsupported value" error due to a configured `review_model`, surface the error and ask the user whether to override `review_model` for this run.
6. If findings exist, fix them.
7. Repeat steps 5-6 until clean or 10 iterations. Follow "Re-review after fixes" so each re-run includes your latest fixes (especially for `--base` and `--commit`).
8. If any fixes were made after the initial test run, re-run tests (see "Test selection"). If tests fail, fix and return to step 5.
9. Stop after 10 iterations and report remaining issues with context.

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
- Do not add ad-hoc liveness checks while `codex review` is running (for example, extra status commands) unless there are clear error signals or an unusually long stall.
