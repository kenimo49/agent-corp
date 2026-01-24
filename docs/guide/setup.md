# セットアップガイド

agent-corpの環境構築からエージェント起動までの手順を説明します。

---

## 動作環境

### 必須要件

| 項目 | 要件 |
|------|------|
| OS | Linux, macOS, WSL2 |
| tmux | 3.0以上 |
| Bash | 4.0以上 |
| Git | 2.0以上 |

### LLMエージェント（いずれか1つ）

| エージェント | インストール方法 |
|-------------|-----------------|
| Claude Code | `npm install -g @anthropic-ai/claude-code` |
| Aider | `pip install aider-chat` |
| GPT CLI | 各ツールのドキュメントを参照 |

---

## インストール手順

### 1. リポジトリのクローン

```bash
git clone https://github.com/kenimo49/agent-corp.git
cd agent-corp
```

### 2. tmuxのインストール

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install tmux
```

**macOS (Homebrew):**
```bash
brew install tmux
```

**確認:**
```bash
tmux -V
# tmux 3.x
```

### 3. LLMエージェントのインストール

**Claude Code（推奨）:**
```bash
npm install -g @anthropic-ai/claude-code

# APIキーの設定
export ANTHROPIC_API_KEY="your-api-key"
```

**Aider:**
```bash
pip install aider-chat

# APIキーの設定（OpenAI）
export OPENAI_API_KEY="your-api-key"
```

### 4. 共有ディレクトリの初期化

```bash
./scripts/init-shared.sh
```

出力例:
```
共有ディレクトリを初期化中: ./shared
完了: 35 ディレクトリを作成しました
```

### 5. 動作確認

```bash
# E2Eテストの実行
./scripts/test-e2e.sh

# ヘルスチェック
./scripts/health.sh check
```

---

## クイックスタート

### セッションの起動

```bash
# デフォルト（Claude Code）で起動
./scripts/start.sh start

# Aiderで起動
./scripts/start.sh start --llm aider

# 起動確認
./scripts/start.sh status
```

### セッションへのアタッチ

```bash
./scripts/start.sh attach
```

### tmuxの基本操作

| 操作 | キー |
|------|------|
| ウィンドウ切り替え | `Ctrl+b` → `n` (次) / `p` (前) |
| ウィンドウ一覧 | `Ctrl+b` → `w` |
| ペイン切り替え | `Ctrl+b` → 矢印キー |
| セッションからデタッチ | `Ctrl+b` → `d` |
| ペイン最大化/復元 | `Ctrl+b` → `z` |

### セッションの終了

```bash
./scripts/start.sh stop
```

---

## ウィンドウ構成

起動後のtmuxセッションは以下の構成になります：

```
agent-corp (tmux session)
├── 0: ceo       - CEO AI
├── 1: pm        - PM AI
├── 2: engineers - Frontend / Backend / Security (3ペイン)
└── 3: monitor   - 共有ディレクトリ監視
```

### 各ウィンドウの役割

| ウィンドウ | 役割 | プロンプト |
|-----------|------|----------|
| ceo | 戦略的指示 | `prompts/ceo.md` |
| pm | タスク管理 | `prompts/pm.md` |
| engineers | 実装 | `prompts/engineers/*.md` |
| monitor | 監視 | - |

---

## 設定のカスタマイズ

### 環境変数

```bash
# 共有ディレクトリのパス
export SHARED_DIR="./shared"

# ログレベル
export LOG_LEVEL="info"  # debug, info, warn, error
```

### スクリプトのオプション

**start.sh:**
```bash
./scripts/start.sh start --llm claude    # LLMの指定
./scripts/start.sh start --dry-run       # 実行せずにコマンド確認
```

**msg.sh:**
```bash
./scripts/msg.sh send --priority critical  # 優先度の指定
./scripts/msg.sh list --limit 50           # 表示件数
./scripts/msg.sh watch --interval 3        # 監視間隔
```

---

## ディレクトリ構成

```
agent-corp/
├── CLAUDE.md              # AIエージェント向けガイド
├── README.md              # プロジェクト概要
├── ROADMAP.md             # 開発ロードマップ
├── prompts/               # システムプロンプト
│   ├── ceo.md
│   ├── pm.md
│   └── engineers/
├── scripts/               # 管理スクリプト
│   ├── start.sh           # セッション起動
│   ├── msg.sh             # メッセージ管理
│   ├── monitor.sh         # 監視・ログ
│   ├── health.sh          # ヘルスチェック
│   ├── init-shared.sh     # 初期化
│   └── test-e2e.sh        # E2Eテスト
├── shared/                # エージェント間共有
│   ├── requirements/      # 要件
│   ├── instructions/      # 指示
│   ├── tasks/             # タスク
│   ├── reports/           # 報告
│   └── ...
├── docs/                  # ドキュメント
└── tests/                 # テスト
```

---

## 次のステップ

1. **[ユースケース集](./usecases.md)** - 実際の使用例
2. **[トラブルシューティング](./troubleshooting.md)** - 問題解決
3. **[CLAUDE.md](../../CLAUDE.md)** - AIエージェント向け詳細ガイド

---

## 更新履歴

- 2025-01-24: 初版作成
