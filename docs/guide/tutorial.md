# チュートリアルガイド

agent-corpを使って実際に開発タスクを実行するチュートリアルです。

---

## 目次

1. [チュートリアル1: 初めてのタスク実行](#チュートリアル1-初めてのタスク実行)
2. [チュートリアル2: メッセージの流れを理解する](#チュートリアル2-メッセージの流れを理解する)
3. [チュートリアル3: 複数エージェントでの協調作業](#チュートリアル3-複数エージェントでの協調作業)
4. [チュートリアル4: カスタム組織構成](#チュートリアル4-カスタム組織構成)
5. [チュートリアル5: 監視とデバッグ](#チュートリアル5-監視とデバッグ)

---

## チュートリアル1: 初めてのタスク実行

最小構成で簡単なタスクを実行します。

### 所要時間
約10分

### 前提条件
- agent-corpのセットアップ完了
- APIキーの設定完了

### ステップ1: 最小構成で起動

```bash
cd agent-corp
./scripts/start.sh --template minimal
```

これにより以下の構成が起動します：
- PM AI（タスク管理）
- Engineer AI（実装）

### ステップ2: tmuxセッションを確認

```bash
# 起動したセッションに接続
tmux attach -t agent-corp

# ウィンドウを切り替え（Ctrl+b n）
```

### ステップ3: 要件を送信

PMウィンドウで以下のメッセージを作成します：

```bash
# 別ターミナルで
./scripts/msg.sh send human pm requirement "hello.pyを作成してください。'Hello, World!'を出力するシンプルなスクリプトです。"
```

### ステップ4: 処理の流れを確認

1. **PM AI** が要件を受け取り、タスクに分解
2. **Engineer AI** にタスクを割り当て
3. **Engineer AI** が実装を実行
4. 完了報告が **PM AI** に返る

### ステップ5: 結果を確認

```bash
# 生成されたファイルを確認
ls -la shared/artifacts/

# メッセージ履歴を確認
./scripts/msg.sh list pm
```

### 完了！

初めてのタスク実行が完了しました。

---

## チュートリアル2: メッセージの流れを理解する

メッセージプロトコルを実際に使って理解を深めます。

### ステップ1: デフォルト構成で起動

```bash
./scripts/start.sh
```

### ステップ2: メッセージ監視を開始

別ターミナルで監視を開始：

```bash
./scripts/msg.sh watch
```

### ステップ3: 要件を送信

```bash
./scripts/msg.sh send human ceo requirement "ユーザー登録機能を追加してください"
```

### ステップ4: メッセージの流れを観察

監視ターミナルで以下の流れが見られます：

```
[12:00:01] human → ceo (requirement)
[12:00:05] ceo → pm (instruction)
[12:00:10] pm → frontend (task)
[12:00:10] pm → backend (task)
[12:00:15] pm → security (task)
```

### ステップ5: 各メッセージを確認

```bash
# CEOの受信メッセージ
./scripts/msg.sh list ceo

# PMの受信メッセージ
./scripts/msg.sh list pm

# 特定のメッセージを読む
./scripts/msg.sh read shared/messages/pm/inbox/task_001.md
```

### メッセージタイプの理解

| タイプ | 方向 | 用途 |
|--------|------|------|
| requirement | human → ceo | 要件定義 |
| instruction | ceo → pm | 戦略的指示 |
| task | pm → engineer | 具体的タスク |
| report | engineer → pm | 完了報告 |
| question | 下位 → 上位 | 質問・確認 |
| answer | 上位 → 下位 | 回答 |

---

## チュートリアル3: 複数エージェントでの協調作業

フロントエンド、バックエンド、セキュリティの3エージェントで協調作業を行います。

### シナリオ
「ログイン機能の実装」- 複数の専門エージェントが協力して実装します。

### ステップ1: 起動

```bash
./scripts/start.sh
```

### ステップ2: 要件を送信

```bash
./scripts/msg.sh send human ceo requirement "$(cat <<'EOF'
# ログイン機能の実装

## 要件
- メールアドレスとパスワードでログイン
- ログイン状態の保持
- セキュアな認証処理

## 成果物
- ログインフォーム (Frontend)
- 認証API (Backend)
- セキュリティレビュー (Security)
EOF
)"
```

### ステップ3: 各エージェントの作業を確認

tmuxでウィンドウを切り替えて確認：

```bash
# Ctrl+b w でウィンドウ一覧
# engineers ウィンドウを選択
```

3つのペインで並行作業が進行：
- **Frontend**: ログインフォームUI
- **Backend**: 認証APIエンドポイント
- **Security**: 脆弱性チェック

### ステップ4: 成果物を確認

```bash
# フロントエンド成果物
ls shared/artifacts/frontend/

# バックエンド成果物
ls shared/artifacts/backend/

# セキュリティレポート
ls shared/artifacts/security/
```

### ステップ5: 統合結果の確認

```bash
# PMの統合レポートを確認
./scripts/msg.sh list ceo --type report
```

---

## チュートリアル4: カスタム組織構成

プロジェクトに合わせた組織構成を作成します。

### シナリオ
データ分析チーム用の構成を作成します。

### ステップ1: テンプレートを作成

```bash
cat > config/org-templates/data-team.yaml << 'EOF'
name: "Data Analysis Team"
description: "データ分析チーム構成"

hierarchy:
  - role: data_lead
    reports_to: human
    subordinates:
      - data_engineer
      - data_analyst
      - ml_engineer

  - role: data_engineer
    reports_to: data_lead
    subordinates: []

  - role: data_analyst
    reports_to: data_lead
    subordinates: []

  - role: ml_engineer
    reports_to: data_lead
    subordinates: []

custom_roles:
  data_lead:
    name: "Data Lead AI"
    prompt: "prompts/custom/data-lead.md"
    description: "データチームリード"

  data_engineer:
    name: "Data Engineer AI"
    prompt: "prompts/custom/data-engineer.md"
    description: "データパイプライン構築"

  data_analyst:
    name: "Data Analyst AI"
    prompt: "prompts/custom/data-analyst.md"
    description: "データ分析・可視化"

  ml_engineer:
    name: "ML Engineer AI"
    prompt: "prompts/custom/ml-engineer.md"
    description: "機械学習モデル開発"

communication:
  flows:
    - from: human
      to: data_lead
      types: [requirement]
    - from: data_lead
      to: [data_engineer, data_analyst, ml_engineer]
      types: [task]
    - from: [data_engineer, data_analyst, ml_engineer]
      to: data_lead
      types: [report, question]

tmux:
  windows:
    - name: lead
      roles: [data_lead]
    - name: team
      layout: even-horizontal
      roles: [data_engineer, data_analyst, ml_engineer]
    - name: monitor
      command: "watch -n 2 'ls -la shared/'"
EOF
```

### ステップ2: カスタムプロンプトを作成

```bash
mkdir -p prompts/custom

# Data Lead プロンプト
cat > prompts/custom/data-lead.md << 'EOF'
# Data Lead AI

## 役割と責任
- データプロジェクトの全体管理
- タスクの優先順位付け
- チームメンバーへの作業割り当て
- 品質管理とレビュー

## チームメンバー
- Data Engineer: データパイプライン担当
- Data Analyst: 分析・可視化担当
- ML Engineer: モデル開発担当

## 行動指針
1. データ品質を最優先
2. 再現可能な分析を心がける
3. ドキュメントを重視
EOF

# 他のプロンプトも同様に作成...
```

### ステップ3: カスタム構成で起動

```bash
./scripts/start.sh --template data-team
```

### ステップ4: 動作確認

```bash
# 分析タスクを送信
./scripts/msg.sh send human data_lead requirement "売上データの傾向分析を行ってください"
```

---

## チュートリアル5: 監視とデバッグ

システムの監視とトラブルシューティングの方法を学びます。

### ステップ1: ダッシュボードを開く

```bash
# ブラウザでダッシュボードを開く
open tools/dashboard.html
# または
xdg-open tools/dashboard.html
```

### ステップ2: リアルタイム監視

```bash
# メッセージ監視
./scripts/msg.sh watch

# システム統計
./scripts/monitor.sh stats
```

### ステップ3: ログの確認

```bash
# リアルタイムログ
./scripts/monitor.sh log

# 特定エージェントのログ
./scripts/monitor.sh log --agent pm
```

### ステップ4: ヘルスチェック

```bash
# システム全体のチェック
./scripts/health.sh check

# 問題があれば自動修復
./scripts/health.sh fix
```

### ステップ5: デバッグモード

```bash
# デバッグモードで起動
AGENT_CORP_DEBUG=1 ./scripts/start.sh

# 詳細ログを確認
tail -f logs/debug.log
```

### ステップ6: ログのエクスポート

```bash
# 分析用にエクスポート
./scripts/monitor.sh export

# JSON形式で出力
./scripts/monitor.sh export --format json
```

### トラブルシューティングのヒント

| 症状 | 確認項目 | 対処 |
|------|---------|------|
| エージェントが応答しない | APIキー設定 | `.env`を確認 |
| メッセージが届かない | 共有ディレクトリ | `health.sh fix` |
| tmuxセッションがない | セッション状態 | `start.sh`で再起動 |

---

## 次のステップ

チュートリアルを完了したら、以下を試してみてください：

1. **実際のプロジェクト**で使ってみる
2. **カスタムプロンプト**で専門性を高める
3. **大規模構成**でチーム開発をシミュレート
4. **CI/CDパイプライン**に組み込む

---

## 関連ドキュメント

- [セットアップガイド](./setup.md) - 初期設定
- [設定ガイド](./configuration.md) - 詳細設定
- [ユースケース集](./usecases.md) - 実践的な活用例
- [トラブルシューティング](./troubleshooting.md) - 問題解決
