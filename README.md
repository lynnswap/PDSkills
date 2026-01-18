# PDSkills
English | [日本語](README.ja.md)

Skill definitions and packaging helper tools for Codex and Claude.

## Overview
- Store skill sources under `skills/`.
- Generate `.skill` packages under `dist/`.
- Create symlinks in `~/.codex/skills` and `~/.claude/skills`.

## Quick Start
```sh
./scripts/deploy_skills.sh
```

## Add or Update Skills
1. Create or edit a folder under `skills/` (e.g., `skills/my-skill/`).
2. Run `./scripts/deploy_skills.sh`.
3. Check that `dist/<name>.skill` is generated and symlinks are updated.

## Requirements
- `python3` and `pip`
- Codex's skill-creator must exist at  
  `~/.codex/skills/.system/skill-creator/scripts/package_skill.py`

## Repository Layout
- `skills/`: Skill definition sources
- `dist/`: Generated `.skill` packages
- `scripts/`: Helper scripts (including deploy)
- `Sources/`: Swift package sources (currently minimal)

## License
MIT. See `LICENSE` for details.
