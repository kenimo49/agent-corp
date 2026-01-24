---
type: knowledge
category: infrastructure
priority: high
created_at: 2025-01-24
tags: [tmux, session-management, multi-agent]
---

# tmux統合ガイド

agent-corpにおけるtmuxセッション管理と複数エージェントの並列実行方法。

---

## 概要

tmuxは複数のエージェントを同時に実行し、監視するための基盤です。

```
┌─────────────────────────────────────────────────────────┐
│ tmux session: agent-corp                                │
├─────────────┬─────────────┬─────────────┬──────────────┤
│   [ceo]     │    [pm]     │ [engineers] │  [monitor]   │
│             │             │  ┌────────┐ │              │
│  CEO AI     │   PM AI     │  │Frontend│ │  watch -n 2  │
│             │             │  ├────────┤ │  'ls shared/'│
│             │             │  │Backend │ │              │
│             │             │  ├────────┤ │              │
│             │             │  │Security│ │              │
│             │             │  └────────┘ │              │
└─────────────┴─────────────┴─────────────┴──────────────┘
```

---

## セッション構成

### デフォルト構成

```yaml
# config/agents.yaml より
tmux:
  session_name: "agent-corp"
  windows:
    - name: "ceo"
      role: "ceo"
    - name: "pm"
      role: "pm"
    - name: "engineers"
      layout: "main-vertical"
      panes:
        - role: "frontend"
        - role: "backend"
        - role: "security"
    - name: "monitor"
      command: "watch -n 2 'ls -la shared/'"
```

### ウィンドウ構成オプション

| ウィンドウ | 目的 | ペイン数 |
|-----------|------|---------|
| ceo | CEO AI実行 | 1 |
| pm | PM AI実行 | 1 |
| engineers | 複数Engineer並列実行 | 3 |
| monitor | 共有ディレクトリ監視 | 1 |

---

## 起動スクリプト

### 基本的な使い方

```bash
# デフォルト起動
./scripts/start.sh

# LLM指定
./scripts/start.sh --llm claude
./scripts/start.sh --llm aider

# テンプレート指定
./scripts/start.sh --template minimal
./scripts/start.sh --template large
```

### スクリプト内部処理

```bash
#!/bin/bash
# scripts/start.sh の主要処理

# 1. セッション作成
tmux new-session -d -s agent-corp

# 2. CEOウィンドウ
tmux rename-window -t agent-corp:0 'ceo'
tmux send-keys -t agent-corp:ceo "claude --system-prompt prompts/ceo.md" C-m

# 3. PMウィンドウ
tmux new-window -t agent-corp -n 'pm'
tmux send-keys -t agent-corp:pm "claude --system-prompt prompts/pm.md" C-m

# 4. Engineersウィンドウ（3ペイン）
tmux new-window -t agent-corp -n 'engineers'
tmux send-keys -t agent-corp:engineers "claude --system-prompt prompts/engineers/frontend.md" C-m
tmux split-window -t agent-corp:engineers -v
tmux send-keys "claude --system-prompt prompts/engineers/backend.md" C-m
tmux split-window -t agent-corp:engineers -v
tmux send-keys "claude --system-prompt prompts/engineers/security.md" C-m
tmux select-layout -t agent-corp:engineers main-vertical

# 5. モニターウィンドウ
tmux new-window -t agent-corp -n 'monitor'
tmux send-keys -t agent-corp:monitor "watch -n 2 'ls -la shared/'" C-m
```

---

## レイアウトオプション

### 利用可能なレイアウト

| レイアウト | 説明 | 用途 |
|-----------|------|------|
| `even-horizontal` | 水平均等分割 | 2-3エージェント |
| `even-vertical` | 垂直均等分割 | 2-3エージェント |
| `main-horizontal` | メイン上 + サブ下 | リーダー + メンバー |
| `main-vertical` | メイン左 + サブ右 | リーダー + メンバー |
| `tiled` | タイル状配置 | 4+エージェント |

### レイアウト設定例

```yaml
# config/org-templates/*.yaml
tmux:
  windows:
    - name: team
      layout: main-vertical  # リーダーが左、メンバーが右
      roles: [lead, dev1, dev2, dev3]
```

### レイアウト変更コマンド

```bash
# セッション内でレイアウト変更
# Ctrl+b, Space でレイアウトを順次切り替え

# 特定レイアウトに変更
tmux select-layout -t agent-corp:engineers main-vertical
tmux select-layout -t agent-corp:engineers tiled
```

---

## セッション操作

### 基本操作

| 操作 | コマンド | キーバインド |
|------|---------|-------------|
| セッション接続 | `tmux attach -t agent-corp` | - |
| セッション一覧 | `tmux ls` | - |
| セッション終了 | `tmux kill-session -t agent-corp` | - |
| デタッチ | - | `Ctrl+b d` |

### ウィンドウ操作

| 操作 | キーバインド |
|------|-------------|
| ウィンドウ一覧 | `Ctrl+b w` |
| 次のウィンドウ | `Ctrl+b n` |
| 前のウィンドウ | `Ctrl+b p` |
| ウィンドウ番号で移動 | `Ctrl+b [0-9]` |

### ペイン操作

| 操作 | キーバインド |
|------|-------------|
| ペイン間移動 | `Ctrl+b 矢印キー` |
| ペイン最大化/復元 | `Ctrl+b z` |
| ペイン分割（水平） | `Ctrl+b "` |
| ペイン分割（垂直） | `Ctrl+b %` |

---

## 監視とデバッグ

### モニターウィンドウ

```bash
# 共有ディレクトリの変更を監視
watch -n 2 'ls -la shared/'

# メッセージフローを監視
watch -n 1 'find shared/messages -name "*.md" | head -20'

# 特定エージェントのinboxを監視
watch -n 1 'ls -la shared/messages/pm/inbox/'
```

### ログ確認

```bash
# 各ウィンドウの出力をファイルに保存
tmux pipe-pane -t agent-corp:ceo 'cat >> logs/ceo.log'
tmux pipe-pane -t agent-corp:pm 'cat >> logs/pm.log'

# スクロールバックで過去の出力を確認
# Ctrl+b [ でコピーモードに入り、矢印キーでスクロール
# q で終了
```

### トラブルシューティング

```bash
# セッションが残っている場合
tmux kill-server  # 全セッション終了

# 特定ウィンドウのみ再起動
tmux kill-window -t agent-corp:pm
tmux new-window -t agent-corp -n 'pm'
tmux send-keys -t agent-corp:pm "claude --system-prompt prompts/pm.md" C-m
```

---

## カスタム構成

### 新規ウィンドウ追加

```bash
# 実行中のセッションに追加
tmux new-window -t agent-corp -n 'debug'
tmux send-keys -t agent-corp:debug "tail -f logs/debug.log" C-m
```

### ペイン追加

```bash
# 既存ウィンドウにペインを追加
tmux split-window -t agent-corp:engineers -h
tmux send-keys "claude --system-prompt prompts/engineers/qa.md" C-m
```

### 設定ファイルでのカスタマイズ

```yaml
# config/org-templates/custom.yaml
tmux:
  windows:
    # 標準ウィンドウ
    - name: lead
      roles: [tech_lead]

    # 複数ペインウィンドウ
    - name: devs
      layout: tiled
      roles: [dev1, dev2, dev3, dev4]

    # カスタムコマンドウィンドウ
    - name: logs
      command: "./scripts/monitor.sh log"

    # 複数コマンドウィンドウ
    - name: dashboard
      panes:
        - command: "./scripts/monitor.sh dashboard"
        - command: "./scripts/health.sh watch"
```

---

## ベストプラクティス

### 1. セッション命名規則

```bash
# プロジェクト名を含める
tmux new-session -s "agent-corp-myproject"

# 環境を区別
tmux new-session -s "agent-corp-dev"
tmux new-session -s "agent-corp-prod"
```

### 2. ウィンドウ構成のヒント

- **階層ごとにウィンドウを分ける**: CEO、PM、Engineersを別ウィンドウに
- **モニター用ウィンドウを用意**: 常に状態を確認できるように
- **ログウィンドウを追加**: デバッグ時に便利

### 3. 自動化スクリプト

```bash
# セッション存在確認と起動
if ! tmux has-session -t agent-corp 2>/dev/null; then
    ./scripts/start.sh
fi
tmux attach -t agent-corp
```

---

## 関連ドキュメント

- [セットアップガイド](../guide/setup.md) - 初期設定
- [設定ガイド](../guide/configuration.md) - 詳細設定
- [組織階層](../design/org-hierarchy.md) - 階層構造
