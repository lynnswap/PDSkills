# PDSkills
[English](README.md) | 日本語

Codex と Claude 向けのスキル定義とパッケージング補助ツール群。

## 概要
- 共通のスキルは `skills/` に配置する。
- Codex 専用は `skills/codex/`、Claude 専用は `skills/claude/` に配置する。
- `.skill` のパッケージは `dist/<target>/` に生成する。
- `~/.codex/skills` と `~/.claude/skills` にシンボリックリンクを張る。

## クイックスタート
```sh
./scripts/deploy_skills.sh
```

## 対象を絞ってデプロイ
```sh
./scripts/deploy_skills.sh --target codex
./scripts/deploy_skills.sh --target claude
```

## スキルの追加・更新
1. `skills/`（共通）、`skills/codex/`、`skills/claude/` 配下にフォルダを作成または編集する。
2. `./scripts/deploy_skills.sh` を実行する（必要なら `--target codex|claude`）。
3. `dist/<target>/<name>.skill` の生成とリンク更新を確認する。

## 必要要件
- `python3` と `pip`
- Codex の skill-creator が以下に存在すること  
  `~/.codex/skills/.system/skill-creator/scripts/package_skill.py`

## リポジトリ構成
- `skills/`: 共通スキル定義のソース
- `skills/codex/`: Codex 専用のスキル定義
- `skills/claude/`: Claude 専用のスキル定義
- `dist/<target>/`: 生成された `.skill` パッケージ（対象別）
- `scripts/`: 補助スクリプト（デプロイ含む）
- `Sources/`: Swift パッケージのソース（現状は最小構成）

## ライセンス
MIT。詳細は `LICENSE` を参照。
