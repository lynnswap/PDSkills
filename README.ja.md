# PDSkills
[English](README.md) | 日本語

Codex と Claude 向けのスキル定義とパッケージング補助ツール群。

## 概要
PDSkills は Codex と Claude 向けの再利用可能なスキルを管理するための小さなツールキットです。
スキルの `.skill` パッケージ化とローカルのスキルカタログ更新を簡単にします。

## クイックスタート
```sh
./scripts/deploy_skills.sh
```

## サポートスキル
- `codex-review` (Codex): Codex CLI で自己レビューを回す。
- `codex-review` (Claude): Claude Code から Codex review を実行する。
- `ios-dev-docs`: Xcode IDEIntelligenceChat AdditionalDocumentation を使って iOS 開発の質問に答える。
- `branch-commit-pr`: 作業中の変更を新しいブランチに移し、`codex-review` を実行して PR を作成する。
- `git-branch-workflow`: 作業開始前に新規ブランチを作成して push し、最後にコミットする。


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
