# RAG機能（プロジェクトコンテキスト自動注入）

RAG（Retrieval-Augmented Generation）機能により、エージェントはプロジェクト固有のコンテキストを自動的に取得し、より適切な応答を生成できます。

## 概要

### Before（RAGなし）

```
PM: 「認証APIを実装して」

Backend Engineer（知識なし）:
  → 「一般的なREST API設計で実装します」
  → プロジェクトのDBスキーマを知らない
  → 既存のエラーハンドリング規約を知らない
  → 結果: プロジェクトと一貫性のないコード
```

### After（RAG導入後）

```
PM: 「認証APIを実装して」

Backend Engineer（RAGコンテキスト付き）:
  入力に自動追加:
  ┌────────────────────────────────────────┐
  │ [プロジェクトコンテキスト]               │
  │                                        │
  │ ## データベース構造                      │
  │ - users テーブル: id, email, password_hash │
  │ - sessions テーブル: id, user_id, token │
  │                                        │
  │ ## API設計規約                          │
  │ - エンドポイント: /api/v1/{resource}    │
  │ - エラー形式: { error: { code, message }} │
  │ - 認証: Authorization: Bearer {token}   │
  └────────────────────────────────────────┘

  → 既存の規約に沿ったコード生成
  → 一貫性のあるエラーハンドリング
  → 既存テーブルを活用した設計
```

## 仕組み

```
┌──────────────┐    ┌──────────────────┐    ┌──────────────────┐
│    タスク     │ → │   コンテキスト解析  │ → │  プロンプト構築   │
│ 「認証実装」  │    │ analyze-context.sh │    │ システムプロンプト │
└──────────────┘    └──────────────────┘    │ + RAGコンテキスト │
                                            │ + タスク内容      │
                                            └────────┬─────────┘
                                                     │
                                                     ▼
                                            ┌──────────────────┐
                                            │     LLM実行      │
                                            │  (Claude/Codex)  │
                                            └──────────────────┘
```

### 解析内容

| 項目 | 説明 |
|------|------|
| ディレクトリ構造 | `tree` コマンドでプロジェクト構造を取得 |
| 技術スタック | package.json, requirements.txt等から自動推定 |
| 関連ファイル | タスク内容のキーワードでgrep検索 |
| APIエンドポイント | Express/Fastifyスタイルのルート定義を検出 |
| DBスキーマ | Prisma/SQLファイルからスキーマを抽出 |
| ドキュメント | README.md, CLAUDE.md等の抜粋 |

## 設定

### 環境変数

| 変数名 | デフォルト値 | 説明 |
|--------|-------------|------|
| `ENABLE_RAG` | `true` | RAG機能の有効/無効 |
| `AGENT_KNOWLEDGE_DIR` | `~/.agent-corp/knowledge` | ナレッジディレクトリ |
| `RAG_CONTEXT_MAX_LINES` | `200` | コンテキストの最大行数 |
| `RAG_CACHE_TTL` | `0` | キャッシュ有効期間（秒、0=毎回更新） |

### 使用例

```bash
# RAG有効（デフォルト）
./scripts/start.sh start

# RAG無効
ENABLE_RAG=false ./scripts/start.sh start

# コンテキスト行数を増やす
RAG_CONTEXT_MAX_LINES=500 ./scripts/start.sh start

# カスタムナレッジディレクトリ
AGENT_KNOWLEDGE_DIR=/path/to/knowledge ./scripts/start.sh start
```

### プロジェクト設定ファイル（.agent-config.yaml）

```yaml
# .agent-config.yaml
rag:
  enabled: true
  knowledge_dir: ~/.agent-corp/knowledge
  max_lines: 200
  cache_ttl: 0
```

## ディレクトリ構造

```
$AGENT_KNOWLEDGE_DIR/                  # デフォルト: ~/.agent-corp/knowledge/
├── global/                            # 全プロジェクト共通ナレッジ
│   ├── coding-standards.md            # コーディング規約（手動作成）
│   └── security-checklist.md          # セキュリティチェックリスト（手動作成）
└── projects/                          # プロジェクト別
    └── {project-hash}/                # プロジェクトパスのハッシュ
        └── context-cache.md           # 最新コンテキスト（自動生成）
```

### グローバルナレッジの追加

`$AGENT_KNOWLEDGE_DIR/global/` にMarkdownファイルを配置すると、全プロジェクトで共通のコンテキストとして注入されます。

```bash
# 例: コーディング規約を追加
mkdir -p ~/.agent-corp/knowledge/global
cat > ~/.agent-corp/knowledge/global/coding-standards.md << 'EOF'
# コーディング規約

## 命名規則
- 変数名: camelCase
- 定数: UPPER_SNAKE_CASE
- クラス名: PascalCase

## エラーハンドリング
- 必ずtry-catchでラップ
- エラーログは必ず出力
EOF
```

## コンテキスト解析スクリプト

### 単体実行

```bash
# 現在のディレクトリを解析
./scripts/analyze-context.sh

# 指定ディレクトリ + タスク内容で解析
./scripts/analyze-context.sh /path/to/project "認証機能を実装"

# 生成されたコンテキストを確認
cat ~/.agent-corp/knowledge/projects/*/context-cache.md
```

### 出力例

```markdown
# プロジェクトコンテキスト

**生成日時:** 2026-01-25 10:30:00
**プロジェクトパス:** /home/user/my-project

---

## ディレクトリ構造

├── src/
│   ├── controllers/
│   ├── models/
│   └── routes/
├── package.json
└── README.md

## 技術スタック

### Node.js プロジェクト

**依存関係:**
express
jsonwebtoken
prisma

**npm scripts:**
- start: node src/index.js
- test: jest

## タスク関連ファイル

**検索キーワード:** 認証 auth login

**関連ファイル:**
src/controllers/authController.ts
src/routes/auth.ts

## プロジェクトドキュメント

### README.md（抜粋）

# My Project
...
```

## トラブルシューティング

### RAGコンテキストが注入されない

```bash
# 1. RAGが有効か確認
echo $ENABLE_RAG  # true であること

# 2. 解析スクリプトを手動実行
./scripts/analyze-context.sh
# エラーがないか確認

# 3. ナレッジディレクトリの権限確認
ls -la ~/.agent-corp/knowledge/
```

### コンテキストが大きすぎる

```bash
# 最大行数を減らす
export RAG_CONTEXT_MAX_LINES=100
```

### 特定のファイルを除外したい

`analyze-context.sh` の `tree` コマンドの `-I` オプションでパターンを追加：

```bash
# scripts/analyze-context.sh 内
tree -L 3 -I 'node_modules|.git|__pycache__|.venv|dist|build|custom_dir'
```

## 関連ドキュメント

- [セットアップガイド](../guide/setup.md) - 環境構築と基本設定
- [エージェントプロンプト設計](./agent-prompts.md) - プロンプト作成方法
- [トラブルシューティング](../guide/troubleshooting.md) - 問題解決
