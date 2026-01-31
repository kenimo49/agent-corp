# エージェント放置時の挙動

## 概要

agent-corpのエージェント群をタスク実行後に放置した場合の挙動と、コスト面での注意点をまとめます。

## 正常系: タスク完了後の自然停止

タスクが正常に完了すると、以下の流れで全エージェントが待機状態になります。

```
Engineer（例: Frontend）のタスク完了
  ↓
PM が各Engineerの報告を集約
  ↓
CEO が PM からの報告を受信・処理
  ↓
一巡してすべてのエージェントが待機状態になる
  ↓
新しいタスクが `shared/tasks/` に配置されるまで停止
```

各エージェントの `agent-loop.sh` は以下のループで動作しています：

1. `shared/tasks/{role}/` を監視
2. タスクファイルがなければスリープ（デフォルト30秒間隔）
3. タスクファイルがあれば処理 → 完了後にスリープへ戻る

タスクが配置されない限り、claude CLI は呼び出されません。**待機中のトークン消費はゼロ**です。

## 注意点: Performance Analyst（PerfAnl）

PerfAnlは他のエージェントと異なり、**定期的に自動実行**されます（`PERF_ANALYST_INTERVAL` 環境変数で制御、デフォルト300秒）。

```bash
# .env での設定
PERF_ANALYST_INTERVAL=300  # 5分ごとに分析実行
```

放置すると5分ごとにclaude CLIが呼び出され、**トークンを消費し続けます**。

### PerfAnlの停止方法

```bash
# tmuxペインに Ctrl+C を送信して停止
tmux send-keys -t agent-corp:perf C-c
```

### PerfAnlの再開方法

```bash
# tmuxペインでagent-loopを再起動
tmux send-keys -t agent-corp:perf './scripts/agent-loop.sh performance_analyst' Enter
```

## エージェントが停止してしまうケース

### claude CLI のエラー終了

claude CLIがnon-zeroの終了コードを返すと、以前は `set -e` によりスクリプト全体が終了していました。現在は `set -e` を削除済みで、個別エラーハンドリングで対処しています。

**症状**: ダッシュボードで「停止」と表示される

**対処法**:
```bash
# 該当ロールのペインでagent-loopを再起動
tmux send-keys -t agent-corp:{role} './scripts/agent-loop.sh {role}' Enter

# 例: Frontend
tmux send-keys -t agent-corp:frontend './scripts/agent-loop.sh frontend' Enter
```

### ダッシュボードでの状態確認

```bash
./scripts/dashboard.sh
```

| 表示 | 意味 |
|------|------|
| 稼働中 | タスク処理中 |
| 待機中 | タスク待ち（正常） |
| 停止 | プロセスが終了している（要再起動） |

## 長時間放置時の推奨手順

1. **PerfAnlを停止する**（不要なトークン消費を防ぐ）
   ```bash
   tmux send-keys -t agent-corp:perf C-c
   ```

2. **ダッシュボードで状態確認**
   ```bash
   ./scripts/dashboard.sh
   ```

3. **必要に応じてエージェントを再起動**（停止しているものがあれば）

4. **tmuxセッションはそのまま残してOK**（デタッチしても問題なし）
   ```bash
   # デタッチ: Ctrl+B → D
   # 再アタッチ:
   tmux attach -t agent-corp
   ```

## コスト最適化

| エージェント | 放置時のコスト | 備考 |
|-------------|--------------|------|
| CEO, PM, Engineers, QA, PO | **なし** | タスクがなければclaude CLI未呼出 |
| PerfAnl | **あり** | 5分間隔で定期実行される |
| Intern (Codex) | **なし** | タスクがなければ未呼出 |

長時間離席する場合は、PerfAnlの停止を推奨します。

## 関連ドキュメント

- [token-consumption.md](./token-consumption.md) - トークン消費とコスト最適化
- [tmux-integration.md](./tmux-integration.md) - tmux連携
- [../guide/troubleshooting.md](../guide/troubleshooting.md) - トラブルシューティング
