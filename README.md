# PDSkills
English | [日本語](README.ja.md)

Skill definitions and packaging helper tools for Codex and Claude.

## Overview
- Store common skill sources under `skills/`.
- Store agent-specific skill sources under `skills/codex/` and `skills/claude/`.
- Generate `.skill` packages under `dist/<target>/`.
- Create symlinks in `~/.codex/skills` and `~/.claude/skills`.

## Quick Start
```sh
./scripts/deploy_skills.sh
```

## Deploy a Single Target
```sh
./scripts/deploy_skills.sh --target codex
./scripts/deploy_skills.sh --target claude
```

## Add or Update Skills
1. Create or edit a folder under `skills/` (common), `skills/codex/`, or `skills/claude/`.
2. Run `./scripts/deploy_skills.sh` (optionally `--target codex|claude`).
3. Check that `dist/<target>/<name>.skill` is generated and symlinks are updated.

## Requirements
- `python3` and `pip`
- Codex's skill-creator must exist at  
  `~/.codex/skills/.system/skill-creator/scripts/package_skill.py`

## Repository Layout
- `skills/`: Common skill definition sources
- `skills/codex/`: Codex-only skill definitions
- `skills/claude/`: Claude-only skill definitions
- `dist/<target>/`: Generated `.skill` packages per target
- `scripts/`: Helper scripts (including deploy)
- `Sources/`: Swift package sources (currently minimal)

## License
MIT. See `LICENSE` for details.
