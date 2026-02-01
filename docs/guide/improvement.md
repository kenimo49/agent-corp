# agent-corp 改善方法ガイド

agent-corpの運用中にパフォーマンスやコストの問題を発見し、改善するためのワークフローです。

## 改善サイクルの全体像

```
1. 分析（Performance Analyst）
   ↓
2. 問題の把握（レポート確認）
   ↓
3. 改善策の設計（別セッションのClaudeで相談）
   ↓
4. 実装・反映（コード修正 → コミット）
   ↓
5. リセット → 再起動で反映
```

---

## Step 1: Performance Analyst で分析する

Performance Analyst は usage-log と見積もりデータを分析し、コスト効率・見積もり精度・モデル選択の妥当性をレポートします。

### 実行方法

```bash
# エージェント稼働中でも、別ターミナルから実行可能
./scripts/msg.sh analyze
```

### 出力先

```
shared/reports/engineers/performance_analyst/analysis-YYYYMMDD-HHMMSS-report.md
```

### 分析内容

| 項目 | 説明 |
|------|------|
| ロール別コスト効率 | CEO/PM/Engineer別のトークン消費・コスト |
| 見積もり精度 | ratio = actual / estimated（1.0が理想） |
| 超過タスク | 見積もりの1.5倍を超過したタスク一覧 |
| キャッシュ効率 | cache_read / cache_creation 比率 |
| モデル選択の妥当性 | 各ロールが使用しているモデルの適切性 |

### 分析タイミングの目安

- エージェント組織の1セッション完了後
- コストが想定を超えた時
- タスクの処理時間が異常に長い時
- 定期的な振り返り（週次など）

---

## Step 2: レポートを確認する

```bash
# 最新のレポートを確認
cat shared/reports/engineers/performance_analyst/analysis-*-report.md | tail -1 | xargs cat

# または直接
ls -lt shared/reports/engineers/performance_analyst/ | head -5
```

レポートで注目すべきポイント:

- **ratio < 0.5**: 過大見積もり → プロンプトの見積もりガイドラインを調整
- **ratio > 1.5**: 過小見積もり → タスクサイズが大きすぎる可能性
- **特定ロールのコスト突出**: モデル選択やタスク振り分けの見直し
- **キャッシュ効率が低い**: RAGコンテキストやプロンプトの最適化

---

## Step 3: 別セッションの Claude で改善策を相談する

**重要**: agent-corpの改善は、稼働中のエージェント組織ではなく、**別セッションの Claude Code** で行います。

### なぜ別セッションか

- 稼働中のエージェントはプロジェクトコード（persona-manager等）の開発に集中している
- agent-corp自体のプロンプトやスクリプトを変更するのは「メタ作業」
- 別セッションなら自由にファイルを読み書きでき、変更の影響範囲を確認できる

### 具体的な手順

```bash
# 1. agent-corpディレクトリで別の Claude Code セッションを開く
cd /path/to/agent-corp
claude

# 2. PerfAnl レポートを読ませる
# Claude に以下のように依頼:
#   「shared/reports/engineers/performance_analyst/ の最新レポートを読んで、
#    改善策を提案してください」

# 3. 改善策を実装してもらう
# 例:
#   「prompts/pm.md のタスクサイズ制限を30分→20分に変更してください」
#   「scripts/agent-loop.sh のウォッチドッグ間隔を3分に短縮してください」
#   「prompts/engineers/frontend.md の見積もりガイドラインを更新してください」
```

### よくある改善パターン

| 問題 | 改善対象ファイル | 改善内容 |
|------|-----------------|---------|
| 見積もりが過大 | `prompts/engineers/*.md` | 見積もりガイドラインの係数調整 |
| タスクが大きすぎる | `prompts/pm.md` | Deadline Hint上限の引き下げ |
| 不要なタスク振り分け | `prompts/pm.md` | タスク振り分けルールの追加 |
| CEO/PMのコスト高い | `scripts/config.sh` | モデルをHaikuに変更（レポート転送用） |
| キャッシュ効率低い | `prompts/*.md` | プロンプト構造の最適化 |
| 長時間タスクが見えない | `scripts/agent-loop.sh` | ウォッチドッグ間隔の調整 |

---

## Step 4: 変更をコミット・反映する

```bash
# 変更をコミット
git add -A
git commit -m "feat: 〇〇の改善"
git push

# エージェントを停止
./scripts/start.sh stop

# 未処理タスクをリセット（古いタスクが残っている場合）
./scripts/msg.sh reset --dry-run  # まず確認
./scripts/msg.sh reset            # 実行

# エージェントを再起動（変更が反映される）
./scripts/start.sh start
```

---

## Step 5: 改善効果を検証する

再起動後、しばらく稼働させてから再度 Performance Analyst を実行:

```bash
./scripts/msg.sh analyze
```

前回のレポートと比較して:
- ratio が 1.0 に近づいているか
- コストが下がっているか
- タスク処理時間が適正か

を確認します。

---

## 改善可能なパラメータ一覧

### プロンプト（`prompts/`）

| ファイル | パラメータ | 説明 |
|---------|-----------|------|
| `pm.md` | Deadline Hint上限 | タスクの最大所要時間（現在: 30分） |
| `pm.md` | タスク振り分けルール | どのロールにタスクを割り当てるか |
| `engineers/*.md` | 見積もりガイドライン | ロール別の見積もり係数 |
| `performance_analyst.md` | 分析指示 | 何を分析・レポートするか |

### スクリプト（`scripts/`）

| ファイル | パラメータ | 説明 |
|---------|-----------|------|
| `agent-loop.sh` | `POLL_INTERVAL` | ファイル監視間隔（デフォルト: 5秒） |
| `agent-loop.sh` | ウォッチドッグ間隔 | 長時間タスクの経過表示間隔（現在: 5分） |
| `config.sh` | `*_MODEL` | ロール別のLLMモデル |
| `config.sh` | `SESSION_COST_LIMIT` | セッションコスト上限 |

### 環境変数

```bash
# モデル選択の例
export CEO_MODEL="claude-haiku-4-5-20251001"      # レポート転送はHaikuで十分
export PM_MODEL="claude-sonnet-4-5-20250929"       # タスク分解はSonnet
export FRONTEND_MODEL="claude-sonnet-4-5-20250929" # 実装はSonnet
```

---

## トラブルシューティング

よくある問題は [troubleshooting.md](./troubleshooting.md) を参照してください。
