# PDSkills
English | [日本語](README.ja.md)

Skill definitions and packaging helper tools for Codex and Claude.

## Overview
PDSkills is a small toolkit for managing reusable skills for Codex and Claude.
It packages skills into `.skill` artifacts and updates local skill catalogs so your agents stay in sync.

## Quick Start
```sh
./scripts/deploy_skills.sh
```

## Supported Skills

### Codex
- `codex-review`: Run `codex review` via the Codex CLI and iterate on reviews and fixes.
- `ask-claude`: Consult Claude for questions, feedback, reviews, or discussions.

### Claude Code
- `codex-review`: From Claude Code, run `codex review` via the Codex CLI and iterate on reviews and fixes.
- `ask-codex`: Consult Codex for questions, feedback, reviews, or discussions.

### Common
- `ios-dev-docs`: Use Xcode documentation (IDEIntelligenceChat AdditionalDocumentation) during iOS development tasks to get hints for API usage and implementation.
- `pr-fix`: Address PR review comments by fetching unresolved threads, applying fixes, replying, and resolving threads.
- `ship`: Move in-progress work to a new branch, run `codex-review`, and open a PR back to the base branch.
- `kickoff`: Create and push a new branch before work, then commit at the end.

## Add or Update Skills
1. Create or edit a folder under `skills/common/`, `skills/codex/`, or `skills/claude/`.
2. Run `./scripts/deploy_skills.sh` (optionally `--target codex|claude`).

## Requirements
- `python3` and `pip`
- Codex's skill-creator must exist at  
  `~/.codex/skills/.system/skill-creator/scripts/package_skill.py`

## Repository Layout
- `skills/common/`: Common skill definition sources
- `skills/codex/`: Codex-only skill definitions
- `skills/claude/`: Claude-only skill definitions
- `.dist/<target>/`: Generated `.skill` packages per target
- `scripts/`: Helper scripts (including deploy)
- `Sources/`: Swift package sources (currently minimal)

## License
MIT. See `LICENSE` for details.
