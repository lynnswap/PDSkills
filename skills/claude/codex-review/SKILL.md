---
name: codex-review
description: Run OpenAI Codex CLI reviews from Claude Code. Use when the user asks for a Codex review or mentions triggers like "codex-review", "/codex-review", or "codex review".
---

# Codex Review

## Overview

Run `codex review` and iterate on fixes until the review is clean. Claude Code applies fixes locally and re-runs the review.

## Workflow

1. Confirm the review target.
   - If the user specifies a target, follow it.
   - Otherwise, prefer `--uncommitted` when there are local changes.
   - If there are no local changes, use `--base origin/main` (or the repo default).
2. If the user wants to override the review model, append `-c review_model="MODEL"` to the command (default stays as-is when omitted).
3. If the user wants to override reasoning effort, append `-c model_reasoning_effort="EFFORT"` to the command (default stays as-is when omitted). Use a value supported by the review model.
4. Run `codex review` with the chosen target and any custom prompt (plus the optional `-c review_model="MODEL"` from step 2 and `-c model_reasoning_effort="EFFORT"` from step 3).
5. Read the review output and extract actionable findings.
6. If findings exist, fix them in the codebase and re-run the same review target.
7. Repeat until no findings remain or after 10 loops, then report status.

## Timeout

**Important**: `codex review` can take a long time (several minutes). Always set a **30-minute timeout** (1800000 ms) when running the command to ensure it completes.

## Command templates

```sh
codex review --uncommitted [-c review_model="MODEL"] [-c model_reasoning_effort="EFFORT"]
```

```sh
codex review --base <branch> [-c review_model="MODEL"] [-c model_reasoning_effort="EFFORT"]
```

```sh
codex review --commit <sha> [-c review_model="MODEL"] [-c model_reasoning_effort="EFFORT"]
```

```sh
codex review --base <branch> "<custom review prompt>" [-c review_model="MODEL"] [-c model_reasoning_effort="EFFORT"]
```

## Output handling

- Summarize the review results in a short list.
- If fixes were applied, list the changed files and confirm the re-review is clean.
- If issues remain after the max loops, call out the remaining findings.
