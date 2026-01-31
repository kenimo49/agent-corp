# トークン消費とコスト最適化

## Claude CLI の Usage フィールド

`claude -p --output-format json` で返却されるJSONの `usage` オブジェクトに、トークン消費量が含まれる。

### 主要フィールド

| フィールド | 説明 | コスト計算 |
|-----------|------|-----------|
| `input_tokens` | 送信プロンプトのトークン数 | 入力単価 × 1.0 |
| `output_tokens` | Claude が生成したレスポンスのトークン数 | 出力単価 × 1.0 |
| `cache_creation_input_tokens` | システムプロンプト等のキャッシュ作成トークン（初回のみ発生） | 入力単価 × 1.25 |
| `cache_read_input_tokens` | キャッシュから読み込んだトークン（2回目以降） | 入力単価 × 0.1 |

### コスト計算式

```
入力側コスト = (input_tokens × 1.0 + cache_creation_input_tokens × 1.25 + cache_read_input_tokens × 0.1) × 入力単価
出力側コスト = output_tokens × 出力単価
合計コスト   = 入力側コスト + 出力側コスト
```

> `server_tool_use` や `service_tier` はツール使用回数やレート制限の区分であり、トークンコストとは直接関係しない。

### JSON レスポンス例

```bash
claude -p "hello" --output-format json | jq '.usage'
```

```json
{
  "input_tokens": 3,
  "cache_creation_input_tokens": 17802,
  "cache_read_input_tokens": 0,
  "output_tokens": 12,
  "server_tool_use": {
    "web_search_requests": 0,
    "web_fetch_requests": 0
  },
  "service_tier": "standard"
}
```

## agent-corp での Usage ログ

### 仕組み

`scripts/agent-loop.sh` の `execute_llm` 関数で `--output-format json` を使用し、レスポンスを以下のように分離している：

1. `.result` → mdファイルへの出力（従来通り）
2. `.usage` + `.cost_usd` → `shared/.usage-log.jsonl` へ追記

### ログファイル

- **パス**: `shared/.usage-log.jsonl`
- **形式**: JSONL（1行1レコード）

```jsonl
{"timestamp":"2026-01-31T09:00:00Z","role":"ceo","task":"20260131-001-req.md","model_usage":{"claude-opus-4-5-20251101":{"input_tokens":1500,"output_tokens":800,"cost_usd":0.38},"claude-haiku-4-5-20251001":{"input_tokens":3,"output_tokens":100,"cost_usd":0.01}},"input_tokens":1503,"output_tokens":900,"cache_creation_input_tokens":17000,"cache_read_input_tokens":0,"cost_usd":0.39,"duration_ms":3200,"session_id":"abc123"}
```

### ログに含まれるフィールド

| フィールド | 説明 |
|-----------|------|
| `timestamp` | UTC タイムスタンプ |
| `role` | エージェントのロール（ceo / pm / frontend / backend / security / qa / intern） |
| `task` | 処理したタスクファイル名（例: `20260131-001-req.md`） |
| `input_tokens` | 入力トークン数 |
| `output_tokens` | 出力トークン数 |
| `cache_creation_input_tokens` | キャッシュ作成トークン数 |
| `cache_read_input_tokens` | キャッシュ読み取りトークン数 |
| `model_usage` | モデル別の使用量内訳（オブジェクト。キーがモデルID） |
| `cost_usd` | このリクエストの合計コスト（USD） |
| `duration_ms` | 処理時間（ミリ秒） |
| `session_id` | Claude セッション ID |

> **注意**: `model_usage` には複数のモデルが含まれることがある（例: メイン処理に Opus、内部ルーティングに Haiku）。モデルごとの `input_tokens`・`output_tokens`・`cost_usd` が確認できる。

### ログの活用例

```bash
# 全ロールの合計コスト
jq -s '[.[].cost_usd] | add' shared/.usage-log.jsonl

# ロール別の合計トークン数
jq -s 'group_by(.role) | map({role: .[0].role, total_input: [.[].input_tokens] | add, total_output: [.[].output_tokens] | add})' shared/.usage-log.jsonl

# タスク別のコスト
jq -s 'group_by(.task) | map({task: .[0].task, cost: [.[].cost_usd] | add}) | sort_by(-.cost)' shared/.usage-log.jsonl

# 特定タスクの処理に関わった全ロール
jq -s '[.[] | select(.task | test("T-001"))] | group_by(.role) | map({role: .[0].role, cost: [.[].cost_usd] | add})' shared/.usage-log.jsonl

# 直近10件のログ
tail -10 shared/.usage-log.jsonl | jq .
```

### tmuxペインでの表示

各 `execute_llm` 呼び出し後、tmuxペインに以下のようなログが表示される：

```
12:30:45 [INFO] Token使用量: input=1500 output=800 cost=$0.39 models=[claude-opus-4-5-20251101, claude-haiku-4-5-20251001]
```

## セッションコスト制限

Maxプランのセッション制限（5時間ローリングウィンドウ）に対応するため、`agent-loop.sh` にコスト閾値チェック機能を実装している。

### 環境変数

| 変数 | 説明 | デフォルト |
|------|------|-----------|
| `SESSION_COST_LIMIT` | 5時間セッションのコスト上限（USD） | `0`（無制限） |
| `SESSION_COST_WARN_PCT` | 警告・停止する閾値（%） | `80` |

### 使用例

```bash
# 5時間で$5を上限とし、80%（$4）で一時停止
SESSION_COST_LIMIT=5 ./scripts/agent-loop.sh ceo

# 90%まで許容する場合
SESSION_COST_LIMIT=5 SESSION_COST_WARN_PCT=90 ./scripts/agent-loop.sh pm
```

### 動作

1. 各ポーリングサイクルの末尾で `shared/.usage-log.jsonl` の直近5時間の `cost_usd` を集計
2. `SESSION_COST_LIMIT × SESSION_COST_WARN_PCT / 100` を超えたらループを一時停止
3. 5分ごとに再チェックし、5時間枠のコストが閾値以下に回復したら自動再開

### SESSION_COST_LIMIT の設定値の決め方

Anthropicはセッション上限の具体的な金額を公開していないため、以下の手順で実測する：

1. `SESSION_COST_LIMIT=0`（無制限）で運用し、usageログを蓄積する
2. claude.ai の設定画面でセッション使用率が100%に達した時点の5時間累計コストを確認する
3. その金額を `SESSION_COST_LIMIT` に設定する

```bash
# 直近5時間の累計コストを確認
jq -s --arg since "$(date -u -d '5 hours ago' '+%Y-%m-%dT%H:%M:%SZ')" \
  '[.[] | select(.timestamp >= $since) | .cost_usd // 0] | add // 0' \
  shared/.usage-log.jsonl
```

## コスト最適化のポイント

- **キャッシュの活用**: 同じシステムプロンプトを使うエージェントは2回目以降 `cache_read` になり、入力コストが約1/10になる
- **ロール分担**: 単純な集約・報告タスクにはSonnetを使い、設計・実装タスクにはOpusを使うなどモデルを使い分ける
- **プロンプトの簡潔化**: システムプロンプトが大きいと `cache_creation` コストが増大する

## ロール別モデル設定

`agent-loop.sh` はロールごとに異なるモデルを指定できる。コスト効率のために、タスクの複雑さに応じてモデルを使い分けることを推奨する。

### モデル別コスト比較（100万トークンあたり）

| モデル | Input | Output | 備考 |
|--------|------:|-------:|------|
| Opus 4.5 | $5.00 | $25.00 | 最高品質。複雑な実装タスク向き |
| Sonnet 4.5 / 4 | $3.00 | $15.00 | バランス型。大半のタスクに十分 |
| Haiku 4.5 | $1.00 | $5.00 | 高速・低コスト。単純な集約処理向き |

### 環境変数

| 変数 | 説明 | デフォルト |
|------|------|-----------|
| `CLAUDE_MODEL` | 全ロール共通デフォルト | 空（CLIデフォルト） |
| `CEO_MODEL` | CEO のモデル | `CLAUDE_MODEL` |
| `PM_MODEL` | PM のモデル | `CLAUDE_MODEL` |
| `FRONTEND_MODEL` | Frontend Engineer のモデル | `CLAUDE_MODEL` |
| `BACKEND_MODEL` | Backend Engineer のモデル | `CLAUDE_MODEL` |
| `SECURITY_MODEL` | Security Engineer のモデル | `CLAUDE_MODEL` |
| `QA_MODEL` | QA のモデル | `CLAUDE_MODEL` |
| `INTERN_MODEL` | Intern のモデル | `CLAUDE_MODEL` |

### 使用例

```bash
# 全ロール Sonnet（コスト重視）
CLAUDE_MODEL=sonnet ./scripts/agent-loop.sh ceo

# Engineer だけ Opus、他は Sonnet
CLAUDE_MODEL=sonnet BACKEND_MODEL=opus FRONTEND_MODEL=opus ./scripts/agent-loop.sh backend

# モデル名のエイリアス: sonnet, opus, haiku
# フルネーム指定も可: claude-sonnet-4-5-20250929
```

### 推奨構成例

| ロール | 推奨モデル | 理由 |
|--------|-----------|------|
| CEO | sonnet | 要件分析・報告集約は高品質モデル不要 |
| PM | sonnet | タスク分解は定型的な処理が多い |
| Frontend | opus | UI実装は複雑な判断が必要 |
| Backend | opus | API設計・実装は品質が重要 |
| Security | opus | セキュリティレビューは高い精度が必要 |
| QA | sonnet | テスト実行・レポートはsonnetで十分 |
| Performance Analyst | sonnet | 分析・提案はsonnetで十分 |
| Intern | sonnet | リサーチ・ドキュメント作成はsonnetで十分 |

## Performance Analyst

トークン消費・コスト効率を自動分析する専用ロール。

### 仕組み

- **タイマー駆動**: `PERF_ANALYST_INTERVAL`（デフォルト300秒）間隔でポーリング
- **変更検出**: `shared/.usage-log.jsonl` の行数変化を検出。変化なしの場合はLLM呼び出しをスキップ（コスト0）
- **事前集計**: jqで直近5時間のサマリーを集計してからLLMに渡すことで入力トークンを節約

### タスク見積もり

Engineer/QAが着手前に `shared/.estimates/{role}/{task}-estimate.json` へ見積もりJSONを記録する。

```json
{
  "task_file": "T-001-auth-foundation.md",
  "role": "backend",
  "estimated_at": "2026-01-31T10:30:00Z",
  "estimated_duration_minutes": 15,
  "estimated_complexity": "medium",
  "description": "認証基盤のJWT実装",
  "subtasks": ["JWTミドルウェア作成", "ログインAPI実装"]
}
```

### 超過タスク調査

見積もり時間の1.5倍を超えたタスクについて、以下の観点で調査レポートを生成:

- 見積もりが非現実的だった
- 入力トークンが異常に大きい（コードベーススキャン過多）
- エラーやリトライが発生した
- モデル選択が不適切だった
- タスクのスコープが広すぎた

### 環境変数

| 変数 | 説明 | デフォルト |
|------|------|-----------|
| `PERFORMANCE_ANALYST_MODEL` | Performance Analyst のモデル | `CLAUDE_MODEL` |
| `PERF_ANALYST_INTERVAL` | 分析間隔（秒） | `300` |

### ディレクトリ構造

```
shared/
├── .estimates/                              # 事前見積もり
│   ├── frontend/{task}-estimate.json
│   ├── backend/{task}-estimate.json
│   ├── security/{task}-estimate.json
│   └── qa/{task}-estimate.json
└── reports/engineers/
    └── performance_analyst/                 # 分析レポート出力先
```
