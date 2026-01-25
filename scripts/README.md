# Scripts

agent-corpの管理スクリプト群です。

---

## start.sh

tmuxセッションの起動・管理を行います。

### 使用方法

```bash
./scripts/start.sh [COMMAND] [OPTIONS]
```

### コマンド

| コマンド | 説明 |
|----------|------|
| `start` | セッションを作成し、エージェントを起動（デフォルト） |
| `stop` | セッションを終了 |
| `attach` | 既存のセッションにアタッチ |
| `status` | セッションの状態を表示 |
| `help` | ヘルプを表示 |

### オプション

| オプション | 説明 | デフォルト |
|------------|------|-----------|
| `--llm <type>` | 使用するLLMモード | `claude-loop` |
| `--dry-run` | 実行せずにコマンドを表示 | - |

### LLMモード

| モード | 説明 |
|--------|------|
| `claude-loop` | Claude自動監視モード（推奨） |
| `claude` | Claude Code対話モード |
| `codex-loop` | OpenAI Codex自動監視モード |
| `codex` | OpenAI Codex対話モード |
<!-- | `gemini-loop` | Gemini CLI自動監視モード（現在無効） | -->
<!-- | `gemini` | Gemini CLI対話モード（現在無効） | -->
| `aider` | Aider使用 |
| `gpt` | GPT CLI（未実装） |
| `none` | シェルのみ（デバッグ用） |

### 例

```bash
# デフォルト（claude-loop）で起動
./scripts/start.sh start

# 対話モードで起動
./scripts/start.sh start --llm claude

# コマンド確認のみ
./scripts/start.sh start --dry-run

# セッションにアタッチ
./scripts/start.sh attach

# 終了
./scripts/start.sh stop
```

---

## msg.sh

エージェント間メッセージの送受信を行います。

### 使用方法

```bash
./scripts/msg.sh <COMMAND> [OPTIONS]
```

### コマンド

| コマンド | 説明 |
|----------|------|
| `send` | メッセージを送信 |
| `list` | メッセージ一覧を表示 |
| `read` | メッセージを読み取り |
| `status` | ステータスを更新 |
| `watch` | 新着メッセージを監視 |

### Send オプション

| オプション | 説明 | 必須 |
|------------|------|------|
| `--from <agent>` | 送信元 | Yes |
| `--to <agent>` | 宛先 | Yes |
| `--type <type>` | メッセージタイプ | Yes |
| `--title <title>` | タイトル | Yes |
| `--body <body>` | 本文 | Yes |
| `--priority <pri>` | 優先度（critical/high/medium/low） | No |

### 例

```bash
# 要件を送信
./scripts/msg.sh send --from human --to ceo --type requirement \
    --title "機能追加" --body "ログイン機能を実装してください"

# メッセージ一覧
./scripts/msg.sh list --dir requirements

# メッセージ監視
./scripts/msg.sh watch
```

---

## agent-loop.sh

各エージェントの監視ループを実行します。`start.sh`から自動的に呼び出されます。

### 使用方法

```bash
./scripts/agent-loop.sh <role> [llm_type]
```

### ロール

| ロール | 監視ディレクトリ | 出力ディレクトリ |
|--------|-----------------|-----------------|
| `ceo` | requirements/, reports/pm/, reports/intern/ | instructions/pm/, tasks/intern/, reports/human/ |
| `pm` | instructions/pm/, reports/engineers/ | tasks/*/, reports/pm/ |
| `intern` | tasks/intern/ | reports/intern/ |
| `frontend` | tasks/frontend/ | reports/engineers/frontend/ |
| `backend` | tasks/backend/ | reports/engineers/backend/ |
| `security` | tasks/security/ | reports/engineers/security/ |

### LLMタイプ

| タイプ | 説明 |
|--------|------|
| `claude` | Claude Code（デフォルト） |
| `codex` | OpenAI Codex CLI |
<!-- | `gemini` | Google Gemini CLI（現在無効） | -->

### 環境変数

| 変数 | 説明 | デフォルト |
|------|------|-----------|
| `POLL_INTERVAL` | 監視間隔（秒） | 5 |
| `LLM_TYPE` | 使用するLLM | claude |

### 処理フロー

```
1. 監視ディレクトリをポーリング
2. 新しいファイルを検出
3. claude -p でファイル内容を処理
4. 結果を出力ディレクトリに保存
5. 処理済みマークを記録
6. POLL_INTERVAL秒待機
7. 1に戻る
```

### 例

```bash
# CEOエージェントを手動起動（通常はstart.shから呼ばれる）
./scripts/agent-loop.sh ceo

# Codexで起動
./scripts/agent-loop.sh pm codex

# Geminiで起動（監視間隔を変更）
POLL_INTERVAL=10 ./scripts/agent-loop.sh frontend gemini
```

---

## ウィンドウ構成

`start.sh start`実行後のtmuxセッション：

```
agent-corp (tmux session)
├── 0: ceo       - CEO AI (agent-loop.sh ceo)
├── 1: pm        - PM AI (agent-loop.sh pm)
├── 2: intern    - Intern AI (agent-loop.sh intern)
├── 3: engineers - 3ペイン分割
│   ├── .0: Frontend (agent-loop.sh frontend)
│   ├── .1: Backend (agent-loop.sh backend)
│   └── .2: Security (agent-loop.sh security)
├── 4: monitor   - 共有ディレクトリ監視 (watch)
└── 5: overview  - 6分割オーバービュー（全エージェント監視）
```

### tmux操作

| 操作 | キー |
|------|------|
| ウィンドウ切り替え | `Ctrl+b` → `0`〜`4` |
| ウィンドウ一覧 | `Ctrl+b` → `w` |
| ペイン切り替え | `Ctrl+b` → 矢印キー |
| デタッチ | `Ctrl+b` → `d` |
