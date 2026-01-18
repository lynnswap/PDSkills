# PDSkills
Codex と Claude 向けのスキル定義とパッケージング補助ツール群。

## 概要
- スキルのソースは `skills/` に配置する。
- `.skill` のパッケージは `dist/` に生成する。
- `~/.codex/skills` と `~/.claude/skills` にシンボリックリンクを張る。

## クイックスタート
```sh
./scripts/deploy_skills.sh
```

## スキルの追加・更新
1. `skills/` 配下にフォルダを作成または編集する（例: `skills/my-skill/`）。
2. `./scripts/deploy_skills.sh` を実行する。
3. `dist/<name>.skill` の生成とリンク更新を確認する。

## 必要要件
- `python3` と `pip`
- Codex の skill-creator が以下に存在すること  
  `~/.codex/skills/.system/skill-creator/scripts/package_skill.py`

## リポジトリ構成
- `skills/`: スキル定義のソース
- `dist/`: 生成された `.skill` パッケージ
- `scripts/`: 補助スクリプト（デプロイ含む）
- `Sources/`: Swift パッケージのソース（現状は最小構成）

## ライセンス
MIT。詳細は `LICENSE` を参照。
