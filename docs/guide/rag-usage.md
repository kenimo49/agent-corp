# RAG機能 利用ガイド

RAG（Retrieval-Augmented Generation）機能を使って、エージェントにプロジェクト固有のコンテキストを自動的に提供する方法を説明します。

## TL;DR

```bash
# RAG有効（デフォルト）で起動
./scripts/start.sh start

# コンテキストが自動注入されることを確認
cat ~/.agent-corp/knowledge/projects/*/context-cache.md

# RAG無効で起動（比較用）
ENABLE_RAG=false ./scripts/start.sh start
```

---

## 目次

1. [クイックスタート](#クイックスタート)
2. [RAGの効果を確認する](#ragの効果を確認する)
3. [コンテキストのカスタマイズ](#コンテキストのカスタマイズ)
4. [グローバルナレッジの追加](#グローバルナレッジの追加)
5. [プロジェクト設定ファイル](#プロジェクト設定ファイル)
6. [トラブルシューティング](#トラブルシューティング)

---

## クイックスタート

### RAGが有効になっていることを確認

```bash
# 設定を確認
./scripts/config.sh

# 出力例:
# === RAG Configuration ===
# ENABLE_RAG:           true
# AGENT_KNOWLEDGE_DIR:  /home/user/.agent-corp/knowledge
# RAG_CONTEXT_MAX_LINES: 200
# RAG_CACHE_TTL:        0
# =========================
```

### コンテキストを手動生成して確認

```bash
# プロジェクトコンテキストを生成
./scripts/analyze-context.sh

# 生成されたコンテキストを確認
cat ~/.agent-corp/knowledge/projects/*/context-cache.md
```

### セッション起動

```bash
# RAG有効（デフォルト）で起動
./scripts/start.sh start

# 要件を送信
./scripts/msg.sh send --from human --to ceo --type requirement \
    --title "認証API実装" \
    --body "ユーザー認証APIを実装してください"
```

CEOエージェントは自動的にプロジェクトのコンテキスト（ディレクトリ構造、技術スタック等）を把握した状態でタスクを分析します。

---

## RAGの効果を確認する

### Before: RAGなし

```bash
# RAGを無効化
ENABLE_RAG=false ./scripts/start.sh start

# 要件送信
./scripts/msg.sh send --from human --to ceo --type requirement \
    --title "APIエンドポイント追加" \
    --body "ユーザー情報取得APIを追加してください"

# CEOの指示を確認
cat shared/instructions/pm/*.md
# → 汎用的な指示（プロジェクト固有の情報なし）
```

### After: RAGあり

```bash
# セッション停止・再起動
./scripts/start.sh stop
./scripts/start.sh start  # RAG有効（デフォルト）

# 処理済みマークをクリア
rm -rf shared/.processed/*

# 同じ要件を再送信
./scripts/msg.sh send --from human --to ceo --type requirement \
    --title "APIエンドポイント追加" \
    --body "ユーザー情報取得APIを追加してください"

# CEOの指示を確認
cat shared/instructions/pm/*.md
# → プロジェクト固有のコンテキストを含む具体的な指示
#   例: 「既存の/api/v1/パターンに従い...」
#   例: 「backend/src/routes/に新規ファイル作成...」
```

---

## コンテキストのカスタマイズ

### 解析対象の調整

`scripts/analyze-context.sh` を編集して、解析対象をカスタマイズできます。

#### 除外ディレクトリの追加

```bash
# scripts/analyze-context.sh 内
# tree コマンドの -I オプションを編集

# Before
tree -L 3 -I 'node_modules|.git|__pycache__|.venv|dist|build|.next|.cache|coverage'

# After（例: vendorディレクトリも除外）
tree -L 3 -I 'node_modules|.git|__pycache__|.venv|dist|build|.next|.cache|coverage|vendor'
```

#### 検索対象ファイルタイプの追加

```bash
# scripts/analyze-context.sh 内
# grep の --include オプションを編集

# Before
grep -rl "$kw" "$PROJECT_DIR" \
    --include="*.ts" --include="*.tsx" \
    --include="*.js" --include="*.jsx" \
    --include="*.py" \
    --include="*.go" \
    --include="*.rs" \
    --include="*.md"

# After（例: .yamlファイルも検索）
grep -rl "$kw" "$PROJECT_DIR" \
    --include="*.ts" --include="*.tsx" \
    --include="*.js" --include="*.jsx" \
    --include="*.py" \
    --include="*.go" \
    --include="*.rs" \
    --include="*.md" \
    --include="*.yaml" --include="*.yml"
```

### コンテキスト量の調整

```bash
# コンテキストを増やす（詳細な情報）
export RAG_CONTEXT_MAX_LINES=500

# コンテキストを減らす（トークン節約）
export RAG_CONTEXT_MAX_LINES=100
```

---

## グローバルナレッジの追加

全プロジェクトで共通して使用したいナレッジを追加できます。

### ディレクトリ構造

```
~/.agent-corp/knowledge/
├── global/                    # 全プロジェクト共通
│   ├── coding-standards.md    # コーディング規約
│   ├── security-checklist.md  # セキュリティチェックリスト
│   └── review-guidelines.md   # レビューガイドライン
└── projects/                  # プロジェクト別（自動生成）
    └── {hash}/
        └── context-cache.md
```

### コーディング規約を追加

```bash
mkdir -p ~/.agent-corp/knowledge/global

cat > ~/.agent-corp/knowledge/global/coding-standards.md << 'EOF'
# コーディング規約

## 命名規則
- 変数名: camelCase (例: userName, isActive)
- 定数: UPPER_SNAKE_CASE (例: MAX_RETRY_COUNT)
- クラス名: PascalCase (例: UserService)
- ファイル名: kebab-case (例: user-service.ts)

## コードスタイル
- インデント: スペース2つ
- 最大行長: 100文字
- セミコロン: 必須

## コメント
- 関数には必ずJSDocコメント
- 複雑なロジックには説明コメント
- TODOコメントには担当者と期限を記載
EOF
```

### セキュリティチェックリストを追加

```bash
cat > ~/.agent-corp/knowledge/global/security-checklist.md << 'EOF'
# セキュリティチェックリスト

## 入力検証
- [ ] ユーザー入力のサニタイズ
- [ ] SQLインジェクション対策
- [ ] XSS対策

## 認証・認可
- [ ] パスワードのハッシュ化（bcrypt）
- [ ] JWTの有効期限設定
- [ ] 権限チェックの実装

## データ保護
- [ ] 機密情報の暗号化
- [ ] ログに機密情報を出力しない
- [ ] 環境変数での秘密情報管理
EOF
```

### 確認

```bash
# グローバルナレッジがコンテキストに含まれることを確認
./scripts/analyze-context.sh | grep -A 20 "グローバルナレッジ"
```

---

## プロジェクト設定ファイル

プロジェクトルートに `.agent-config.yaml` を配置することで、プロジェクト固有の設定が可能です。

### 設定ファイルの作成

```bash
cat > .agent-config.yaml << 'EOF'
# agent-corp プロジェクト設定

rag:
  # RAG機能の有効/無効
  enabled: true

  # ナレッジディレクトリ（デフォルト: ~/.agent-corp/knowledge）
  # knowledge_dir: /custom/path/to/knowledge

  # コンテキストの最大行数
  max_lines: 200

  # キャッシュ有効期間（秒、0=毎回更新）
  cache_ttl: 0
EOF
```

### 設定項目

| 項目 | デフォルト | 説明 |
|------|-----------|------|
| `rag.enabled` | `true` | RAG機能の有効/無効 |
| `rag.knowledge_dir` | `~/.agent-corp/knowledge` | ナレッジディレクトリ |
| `rag.max_lines` | `200` | コンテキストの最大行数 |
| `rag.cache_ttl` | `0` | キャッシュ有効期間（秒） |

### 環境変数との優先順位

```
1. 環境変数（最優先）
2. .agent-config.yaml
3. デフォルト値
```

例:
```bash
# 環境変数で上書き
ENABLE_RAG=false ./scripts/start.sh start
# → .agent-config.yaml の enabled: true は無視される
```

---

## トラブルシューティング

### コンテキストが注入されない

```bash
# 1. RAGが有効か確認
./scripts/config.sh

# 2. 解析スクリプトを手動実行してエラー確認
./scripts/analyze-context.sh
# エラーがないか確認

# 3. ナレッジディレクトリの権限確認
ls -la ~/.agent-corp/knowledge/

# 4. スクリプトの実行権限確認
ls -la scripts/analyze-context.sh
# なければ: chmod +x scripts/analyze-context.sh
```

### コンテキストが大きすぎる

```bash
# 最大行数を減らす
export RAG_CONTEXT_MAX_LINES=100

# または .agent-config.yaml で設定
# rag:
#   max_lines: 100
```

### 特定のファイル/ディレクトリを除外したい

`scripts/analyze-context.sh` の `tree` コマンドを編集:

```bash
# Before
tree -L 3 -I 'node_modules|.git|...'

# After（例: logsディレクトリを除外）
tree -L 3 -I 'node_modules|.git|...|logs'
```

### キャッシュをクリアしたい

```bash
# プロジェクト別キャッシュをクリア
rm -rf ~/.agent-corp/knowledge/projects/*

# 全てクリア
rm -rf ~/.agent-corp/knowledge
```

### yqがないという警告

設定ファイル（.agent-config.yaml）を使用する場合、`yq` コマンドが必要です:

```bash
# Ubuntu/Debian
sudo apt install yq

# macOS
brew install yq

# または snap
sudo snap install yq
```

yqがない場合でも基本機能は動作しますが、設定ファイルの読み込みは制限されます。

---

## 高度な使い方

### タスク内容に応じた関連ファイル検索

コンテキスト解析はタスク内容からキーワードを抽出し、関連ファイルを検索します:

```bash
# タスク内容を指定してコンテキスト生成
./scripts/analyze-context.sh . "認証機能 JWT トークン"

# 出力に「タスク関連ファイル」セクションが追加される
```

### 複数プロジェクトでの使用

各プロジェクトは独立したコンテキストキャッシュを持ちます:

```
~/.agent-corp/knowledge/projects/
├── abc12345/    # プロジェクトA
├── def67890/    # プロジェクトB
└── ghi11223/    # プロジェクトC
```

プロジェクトを切り替えると、自動的に対応するコンテキストが使用されます。

### CI/CDでの使用

```bash
# CIパイプラインでRAGを無効化（コスト削減）
ENABLE_RAG=false ./scripts/start.sh start

# または必要な場合のみ有効化
ENABLE_RAG=true RAG_CONTEXT_MAX_LINES=50 ./scripts/start.sh start
```

---

## 関連ドキュメント

- [RAG機能ドキュメント](../knowledge/rag-integration.md) - 技術詳細
- [セットアップガイド](./setup.md) - 環境構築
- [チュートリアル](./tutorial.md) - 基本的な使い方
- [トラブルシューティング](./troubleshooting.md) - 問題解決

---

## 更新履歴

- 2026-01-25: 初版作成
