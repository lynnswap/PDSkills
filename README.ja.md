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

### アクション型スキル

明示的に呼び出して実行するスキル。`/skill-name` で起動する。

#### Codex
- `codex-review`: Codex CLI の `codex review` を実行し、レビューと修正を繰り返す。
- `ask-claude`: Claude に質問・相談・レビュー・議論などを依頼する。

#### Claude Code
- `codex-review`: Claude Code から Codex CLI の `codex review` を実行し、レビューと修正を繰り返す。
- `ask-codex`: Codex に質問・相談・レビュー・議論などを依頼する。

#### 共通
- `pr-fix`: PR レビューコメントへの対応を効率化し、未解決スレッド取得・修正・返信・解決を行う。
- `release`: コミット履歴からリリースノートを自動生成し、GitHub リリースを作成する。
- `ship`: 作業中の変更を新しいブランチに移し、`codex-review` を実行して PR を作成する。

### ガイドライン/リファレンス型

開発フローやドキュメント参照のルールを定義するスキル。
これらは単体で呼び出すのではなく、`AGENTS.md` や `CLAUDE.md` から参照して自動適用させる使い方を想定している。

#### 共通
- `xcode-mcp-workflow`: Xcode MCP を使った Apple プラットフォーム開発のワークフローと実用例のガイド。
- `ios-dev-docs`: iOS 開発タスクで Xcode のドキュメント(IDEIntelligenceChat AdditionalDocumentation)を参照するためのガイド。


## スキルの追加・更新
1. `skills/common/`、`skills/codex/`、`skills/claude/` 配下にフォルダを作成または編集する。
2. `./scripts/deploy_skills.sh` を実行する（必要なら `--target codex|claude`）。

## 必要要件
- `python3` と `pip`
- Codex の skill-creator が以下に存在すること  
  `~/.codex/skills/.system/skill-creator/scripts/package_skill.py`

## リポジトリ構成
- `skills/common/`: 共通スキル定義のソース
- `skills/codex/`: Codex 専用のスキル定義
- `skills/claude/`: Claude 専用のスキル定義
- `.dist/<target>/`: 生成された `.skill` パッケージ（対象別）
- `scripts/`: 補助スクリプト（デプロイ含む）
- `Sources/`: Swift パッケージのソース（現状は最小構成）

## ライセンス
MIT。詳細は `LICENSE` を参照。
