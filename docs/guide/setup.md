# セットアップガイド

agent-corpの環境構築からエージェント起動までの手順を説明します。

## 対応LLM

agent-corpは以下のLLMエージェントに対応しています：

| LLM | 説明 | 推奨用途 |
|-----|------|---------|
| **Claude Code** | Anthropic社のCLI（推奨） | 高品質なコード生成・分析 |
| **OpenAI Codex** | OpenAI社のCLI | GPT-4ベースの開発支援 |
<!-- | **Gemini CLI** | Google社のCLI | Geminiモデルによる開発支援（現在無効） | -->

お好みのLLMを選択して使用できます。

## TL;DR

```bash
# 1. 依存関係
sudo apt install tmux

# 2. LLMエージェント（いずれか1つ）
npm install -g @anthropic-ai/claude-code  # Claude
npm install -g @openai/codex              # Codex
# npm install -g @google/gemini-cli       # Gemini（現在無効）

# 3. 認証（選択したLLMに応じて）
claude login                 # Claude（サブスクリプション）
codex login                  # Codex（サブスクリプション）
# gemini auth login          # Gemini（現在無効）

# 4. 起動
./scripts/start.sh start                    # Claude（デフォルト）
./scripts/start.sh start --llm codex-loop   # Codex
# ./scripts/start.sh start --llm gemini-loop  # Gemini（現在無効）

# 5. 確認
./scripts/start.sh attach   # → Ctrl+b 5 で6分割表示
```

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
| OpenAI Codex CLI | `npm install -g @openai/codex` |
<!-- | Gemini CLI | `npm install -g @google/gemini-cli`（現在無効） | -->
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

# 認証（いずれかの方法）
claude login                            # サブスクリプション（Pro/Max/Team）
export ANTHROPIC_API_KEY="your-api-key" # APIキー
```

**OpenAI Codex CLI:**
```bash
npm install -g @openai/codex

# 認証（サブスクリプション推奨）
codex login
# ブラウザが開き、OpenAIアカウントでログイン
# ChatGPT Plus/Pro/Teamのサブスクリプションが必要

# または APIキーで認証
export OPENAI_API_KEY="your-api-key"
```

> **Note**: `codex login` でサブスクリプション認証すると、APIキー不要で利用できます。

<!--
**Google Gemini CLI（現在無効）:**
```bash
npm install -g @google/gemini-cli

# 認証（いずれかの方法）
gemini auth login                      # Googleアカウント認証
export GOOGLE_API_KEY="your-api-key"   # APIキー
```
-->

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
# デフォルト（claude-loop: 自動監視モード）で起動
./scripts/start.sh start

# 起動確認
./scripts/start.sh status
```

### 起動モード

| モード | コマンド | 説明 |
|--------|----------|------|
| claude-loop | `start.sh start` | Claude自動監視・自動処理（推奨） |
| claude | `start.sh start --llm claude` | Claude Code対話モード |
| codex-loop | `start.sh start --llm codex-loop` | Codex自動監視・自動処理 |
| codex | `start.sh start --llm codex` | OpenAI Codex対話モード |
<!-- | gemini-loop | `start.sh start --llm gemini-loop` | Gemini自動監視（現在無効） | -->
<!-- | gemini | `start.sh start --llm gemini` | Gemini CLI対話モード（現在無効） | -->
| aider | `start.sh start --llm aider` | Aider使用 |
| none | `start.sh start --llm none` | シェルのみ（デバッグ用） |

### セッションへのアタッチ

```bash
./scripts/start.sh attach

# 4分割オーバービュー表示
# tmux内で: Ctrl+b → 4
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
├── 2: intern    - Intern AI (Gemini)
├── 3: engineers - Frontend / Backend / Security (3ペイン)
├── 4: monitor   - 共有ディレクトリ監視
└── 5: overview  - 6分割オーバービュー（Ctrl+b → 5）
```

### 各ウィンドウの役割

| ウィンドウ | 役割 | 使用LLM | 説明 |
|-----------|------|---------|------|
| ceo | 戦略的指示 | Claude | 要件を分析しPM/Internへ指示 |
| pm | タスク管理 | Claude | タスク分解、エンジニアへ割り当て |
| intern | 補佐業務 | Claude | リサーチ、ドキュメント作成 |
| engineers | 実装 | Claude | Frontend/Backend/Security |
| monitor | 監視 | - | 共有ディレクトリ変更監視 |
| overview | 全体表示 | - | 6分割でリアルタイム監視 |

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
# 要件を送信
./scripts/msg.sh send --from human --to ceo --type requirement \
    --title "機能追加" --body "ログイン機能を実装してください"

# メッセージ一覧表示
./scripts/msg.sh list --dir requirements --limit 50

# メッセージ監視
./scripts/msg.sh watch --interval 3
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
│   ├── agent-loop.sh      # エージェント監視ループ
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

1. **[チュートリアル](./tutorial.md)** - 実際にタスクを実行してみる
2. **[スクリプトリファレンス](../../scripts/README.md)** - 各スクリプトの詳細
3. **[トラブルシューティング](./troubleshooting.md)** - 問題解決

## 関連ドキュメント

| カテゴリ | ドキュメント | 説明 |
|---------|-------------|------|
| 設計 | [組織階層設計](../design/org-hierarchy.md) | CEO/PM/Engineerの役割 |
| 設計 | [メッセージプロトコル](../design/message-protocol.md) | エージェント間通信 |
| フロー | [要件→タスク変換](../flows/task-assignment/requirement-to-task.md) | 処理の流れ |
| 知識 | [エージェントプロンプト設計](../knowledge/agent-prompts.md) | プロンプト作成方法 |

---

## 更新履歴

- 2026-01-25: claude-loopモード追加、overviewウィンドウ追加
- 2025-01-24: 初版作成
