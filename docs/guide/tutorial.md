# チュートリアルガイド

agent-corpを使って実際に開発タスクを実行するチュートリアルです。

## TL;DR

```bash
# 起動
./scripts/start.sh start

# 要件送信
./scripts/msg.sh send --from human --to ceo --type requirement \
    --title "テスト" --body "Hello Worldを実装してください"

# 4分割画面で確認
./scripts/start.sh attach   # → Ctrl+b 4

# 最終報告
cat shared/reports/human/*.md
```

---

## 目次

1. [チュートリアル1: 初めてのタスク実行](#チュートリアル1-初めてのタスク実行)
2. [チュートリアル2: メッセージの流れを理解する](#チュートリアル2-メッセージの流れを理解する)
3. [チュートリアル3: 複数エージェントでの協調作業](#チュートリアル3-複数エージェントでの協調作業)
4. [チュートリアル4: カスタム組織構成](#チュートリアル4-カスタム組織構成)
5. [チュートリアル5: 監視とデバッグ](#チュートリアル5-監視とデバッグ)

---

## チュートリアル1: 初めてのタスク実行

自動監視モードでタスクを実行します。

### 前提条件
- agent-corpのセットアップ完了
- `ANTHROPIC_API_KEY` 環境変数の設定完了

### ステップ1: セッションを起動

```bash
cd agent-corp
./scripts/start.sh start
```

これにより以下が起動します：
- CEO AI（戦略的指示）
- PM AI（タスク管理）
- Engineer AI x3（Frontend/Backend/Security）
- 監視ウィンドウ
- 4分割オーバービュー

### ステップ2: 4分割オーバービューを確認

```bash
# セッションにアタッチ
./scripts/start.sh attach

# tmux内で4分割画面を表示
# Ctrl+b → 4
```

### ステップ3: 要件を送信

別ターミナルを開いて要件を送信します：

```bash
./scripts/msg.sh send --from human --to ceo --type requirement \
    --title "Hello Worldスクリプト作成" \
    --body "hello.pyを作成してください。'Hello, World!'を出力するシンプルなスクリプトです。"
```

### ステップ4: 処理の流れを確認

4分割画面で自動処理が進行します：

1. **CEO AI** が要件を受け取り、PMへ指示を作成
2. **PM AI** がタスクに分解、各エンジニアへ割り当て
3. **Engineer AI** が実装・報告を作成
4. **PM AI** がCEOへ進捗報告
5. **CEO AI** が人間への最終報告を作成

### ステップ5: 結果を確認

```bash
# 各ディレクトリの状態を確認
ls -la shared/instructions/pm/      # CEOからPMへの指示
ls -la shared/tasks/*/              # PMからエンジニアへのタスク
ls -la shared/reports/engineers/*/  # エンジニアからの報告
ls -la shared/reports/pm/           # PMからCEOへの報告
ls -la shared/reports/human/        # 最終報告
```

### ステップ6: セッション終了

```bash
# tmuxからデタッチ
# Ctrl+b → d

# セッション終了
./scripts/start.sh stop
```

### 完了！

自動監視モードでの初めてのタスク実行が完了しました。

---

## チュートリアル2: メッセージの流れを理解する

ファイルベースのメッセージフローを理解します。

### 処理フロー図

```
human ──→ shared/requirements/
              ↓
           CEO ←─────────────────┐
              ↓                  │
   shared/instructions/pm    shared/reports/pm
              ↓                  ↑
            PM ←─────────────────┤
              ↓                  │
      shared/tasks/*      shared/reports/engineers/*
              ↓                  ↑
        Engineers ───────────────┘
              ↓
     shared/reports/human（最終報告）
```

### ステップ1: セッションを起動

```bash
./scripts/start.sh start
```

### ステップ2: 要件を送信

```bash
./scripts/msg.sh send --from human --to ceo --type requirement \
    --title "ユーザー登録機能" \
    --body "ユーザー登録機能を追加してください"
```

### ステップ3: ファイルの流れを観察

別ターミナルで各ディレクトリを監視：

```bash
# 要件ファイル（human → CEO）
watch -n 2 'ls -la shared/requirements/'

# 指示ファイル（CEO → PM）
watch -n 2 'ls -la shared/instructions/pm/'

# タスクファイル（PM → Engineers）
watch -n 2 'ls -la shared/tasks/*/'

# レポートファイル（Engineers → PM → CEO → Human）
watch -n 2 'ls -la shared/reports/*/'
```

### ステップ4: 各ファイルの内容を確認

```bash
# CEOからPMへの指示
cat shared/instructions/pm/*.md

# PMからエンジニアへのタスク
cat shared/tasks/frontend/*.md

# 最終報告
cat shared/reports/human/*.md
```

### ディレクトリ構造

| ディレクトリ | 方向 | 用途 |
|-------------|------|------|
| requirements/ | human → CEO | 要件定義 |
| instructions/pm/ | CEO → PM | 戦略的指示 |
| tasks/frontend/ | PM → Frontend | フロントエンドタスク |
| tasks/backend/ | PM → Backend | バックエンドタスク |
| tasks/security/ | PM → Security | セキュリティタスク |
| reports/engineers/*/ | Engineer → PM | 各エンジニアの報告 |
| reports/pm/ | PM → CEO | PM統合報告 |
| reports/human/ | CEO → Human | 最終報告 |

---

## チュートリアル3: 複数エージェントでの協調作業

フロントエンド、バックエンド、セキュリティの3エージェントで協調作業を行います。

### シナリオ
「ログイン機能の実装」- 複数の専門エージェントが協力して実装します。

### ステップ1: クリーンな状態で起動

```bash
# 既存ファイルをバックアップ
mv shared shared.bak 2>/dev/null

# セッション起動（sharedディレクトリは自動作成される）
./scripts/start.sh start
```

### ステップ2: 要件を送信

```bash
./scripts/msg.sh send --from human --to ceo --type requirement \
    --title "ログイン機能の実装" \
    --body "$(cat <<'EOF'
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

### ステップ3: 4分割画面で並行処理を確認

```bash
./scripts/start.sh attach
# Ctrl+b → 4 で4分割オーバービュー
```

4つのペインで処理状況を確認：
- **CEO**: 要件分析、PM指示作成
- **PM**: タスク分解、エンジニア割り当て
- **Frontend**: ログインフォームUI設計
- **Backend**: 認証API設計

### ステップ4: エンジニアの報告を確認

```bash
# 各エンジニアの報告
cat shared/reports/engineers/frontend/*.md
cat shared/reports/engineers/backend/*.md
cat shared/reports/engineers/security/*.md
```

### ステップ5: 最終報告を確認

```bash
# PMからCEOへの統合報告
cat shared/reports/pm/*.md

# CEOから人間への最終報告
cat shared/reports/human/*.md
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
./scripts/msg.sh send --from human --to data_lead --type requirement \
    --title "売上データの傾向分析" \
    --body "売上データの傾向分析を行ってください"
```

---

## チュートリアル5: 監視とデバッグ

システムの監視とトラブルシューティングの方法を学びます。

### ステップ1: 4分割オーバービューで監視

```bash
./scripts/start.sh attach
# Ctrl+b → 4 で4分割画面

# 表示内容：
# - CEO: 要件処理、指示作成状況
# - PM: タスク分解状況
# - Frontend: タスク処理状況
# - Backend: タスク処理状況
```

### ステップ2: tmuxでの各ウィンドウ確認

```bash
# ウィンドウ切り替え
Ctrl+b → 0  # CEO
Ctrl+b → 1  # PM
Ctrl+b → 2  # Engineers（3ペイン）
Ctrl+b → 3  # Monitor
Ctrl+b → 4  # Overview

# ウィンドウ一覧
Ctrl+b → w
```

### ステップ3: ファイル監視

```bash
# 共有ディレクトリ全体の変更監視
watch -n 2 'find shared -name "*.md" -mmin -5 | head -20'

# 特定ディレクトリの監視
watch -n 2 'ls -la shared/reports/human/'
```

### ステップ4: セッション状態の確認

```bash
# セッション状態
./scripts/start.sh status

# 処理済みファイル数
ls shared/.processed/ | wc -l
```

### ステップ5: トラブルシューティング

```bash
# 処理済みマークをクリア（再処理させる）
rm -rf shared/.processed/*

# セッション再起動
./scripts/start.sh stop
./scripts/start.sh start

# 古いファイルをクリアして再開
mv shared shared.bak
./scripts/start.sh start
```

### トラブルシューティングのヒント

| 症状 | 確認項目 | 対処 |
|------|---------|------|
| エージェントが動かない | APIキー設定 | `export ANTHROPIC_API_KEY=...` |
| 同じファイルが処理されない | 処理済みマーク | `rm -rf shared/.processed/*` |
| tmuxセッションがない | セッション状態 | `./scripts/start.sh start` |
| 処理が止まっている | tmuxログ | `Ctrl+b → 0` でCEO画面確認 |

---

## 次のステップ

チュートリアルを完了したら、以下を試してみてください：

1. **[RAG機能](./rag-usage.md)** でプロジェクト固有のコンテキストを活用
2. **実際のプロジェクト**で使ってみる
3. **カスタムプロンプト**で専門性を高める
4. **大規模構成**でチーム開発をシミュレート
5. **CI/CDパイプライン**に組み込む

---

## 関連ドキュメント

### ガイド
- [セットアップガイド](./setup.md) - 環境構築・起動方法
- [RAG利用ガイド](./rag-usage.md) - プロジェクトコンテキスト自動注入
- [設定ガイド](./configuration.md) - 詳細設定
- [トラブルシューティング](./troubleshooting.md) - 問題解決

### リファレンス
- [スクリプトリファレンス](../../scripts/README.md) - start.sh, msg.sh, agent-loop.sh

### 設計思想
- [組織階層設計](../design/org-hierarchy.md) - CEO/PM/Engineerの役割
- [メッセージプロトコル](../design/message-protocol.md) - エージェント間通信
- [共有ディレクトリ設計](../design/shared-directory.md) - ファイル共有の仕組み

### 処理フロー
- [要件→タスク変換](../flows/task-assignment/requirement-to-task.md)
- [報告フロー](../flows/agent-communication/report-flow.md)
