# E2Eテストシナリオ

## 概要

agent-corpの基本的な動作を検証するためのE2Eテストシナリオ。
シンプルな「Hello World」タスクを通じて、エージェント間の通信フローを確認する。

---

## テストシナリオ 1: Hello World タスク

### 目的

Human → CEO → PM → Engineer → PM → CEO → Human の全フローが正常に動作することを確認。

### 前提条件

- `shared/` ディレクトリが初期化済み
- 各エージェントのプロンプトが配置済み

### テストステップ

#### Step 1: 要件の作成（Human → CEO）

**アクション**: 人間が要件を作成

```bash
./scripts/msg.sh send \
    --from human \
    --to ceo \
    --type requirement \
    --priority medium \
    --title "Hello Worldプログラムの作成" \
    --body "シンプルなHello Worldプログラムを作成してください。言語はPythonを使用。"
```

**期待結果**:
- `shared/requirements/YYYYMMDD-001-req.md` が作成される
- ステータスが `pending`

#### Step 2: 戦略的指示の作成（CEO → PM）

**アクション**: CEO AIが要件を分析し、PMに指示を送信

```bash
./scripts/msg.sh send \
    --from ceo \
    --to pm \
    --type instruction \
    --priority medium \
    --title "Hello World実装の指示" \
    --body "Backend Engineerに以下のタスクを割り当ててください：
1. hello.py ファイルの作成
2. 'Hello, World!' を出力する機能の実装
3. 動作確認" \
    --parent YYYYMMDD-001-req
```

**期待結果**:
- `shared/instructions/pm/YYYYMMDD-001-inst.md` が作成される

#### Step 3: タスクの割り当て（PM → Backend）

**アクション**: PM AIがタスクを分解し、Backend Engineerに割り当て

```bash
./scripts/msg.sh send \
    --from pm \
    --to backend \
    --type task \
    --priority medium \
    --title "hello.py の実装" \
    --body "## 説明
Hello Worldプログラムを作成してください。

## 完了条件
- [ ] hello.py を作成
- [ ] 実行時に 'Hello, World!' が出力される
- [ ] 動作確認済み

## 技術要件
- Python 3.x
- 標準ライブラリのみ使用" \
    --parent YYYYMMDD-001-inst
```

**期待結果**:
- `shared/tasks/backend/YYYYMMDD-001-task.md` が作成される

#### Step 4: 実装と報告（Backend → PM）

**アクション**: Backend Engineerが実装を完了し、報告

```bash
# 実装（手動またはAIエージェント）
cat > src/hello.py << 'EOF'
#!/usr/bin/env python3
"""Hello World program."""

def main():
    print("Hello, World!")

if __name__ == "__main__":
    main()
EOF

# 報告の送信
./scripts/msg.sh send \
    --from backend \
    --to pm \
    --type report \
    --priority medium \
    --title "hello.py 実装完了" \
    --body "## ステータス
completed

## 完了項目
- [x] hello.py を作成
- [x] 実行時に 'Hello, World!' が出力される
- [x] 動作確認済み

## 成果物
- src/hello.py: Hello World プログラム

## 備考
python3 src/hello.py で実行可能" \
    --parent YYYYMMDD-001-task
```

**期待結果**:
- `shared/reports/engineers/backend/YYYYMMDD-001-rep.md` が作成される
- `src/hello.py` が作成される

#### Step 5: 進捗報告（PM → CEO）

**アクション**: PMがCEOに進捗を報告

```bash
./scripts/msg.sh send \
    --from pm \
    --to ceo \
    --type report \
    --priority medium \
    --title "Hello World実装 進捗報告" \
    --body "## ステータス
completed

## 完了項目
- [x] Backend Engineerがhello.pyを実装
- [x] 動作確認済み

## 成果物
- src/hello.py

## 次のステップ
- なし（タスク完了）" \
    --parent YYYYMMDD-001-inst
```

**期待結果**:
- `shared/reports/pm/YYYYMMDD-001-rep.md` が作成される

#### Step 6: 最終報告（CEO → Human）

**アクション**: CEOが人間に最終報告

```bash
./scripts/msg.sh send \
    --from ceo \
    --to human \
    --type report \
    --priority medium \
    --title "Hello Worldプログラム 完了報告" \
    --body "## ステータス
completed

## 概要
ご依頼のHello Worldプログラムの実装が完了しました。

## 成果物
- src/hello.py: Python 3で動作するHello Worldプログラム

## 実行方法
python3 src/hello.py

## 備考
すべての完了条件を満たしています。" \
    --parent YYYYMMDD-001-req
```

**期待結果**:
- `shared/reports/human/YYYYMMDD-001-rep.md` が作成される

### 検証項目

| 項目 | 確認方法 | 期待値 |
|------|---------|--------|
| 要件ファイル | `ls shared/requirements/` | 1ファイル |
| 指示ファイル | `ls shared/instructions/pm/` | 1ファイル |
| タスクファイル | `ls shared/tasks/backend/` | 1ファイル |
| 報告ファイル（Engineer） | `ls shared/reports/engineers/backend/` | 1ファイル |
| 報告ファイル（PM） | `ls shared/reports/pm/` | 1ファイル |
| 報告ファイル（CEO） | `ls shared/reports/human/` | 1ファイル |
| 成果物 | `python3 src/hello.py` | "Hello, World!" |

---

## テストシナリオ 2: 質問・回答フロー

### 目的

エージェント間の質問・回答フローが正常に動作することを確認。

### テストステップ

#### Step 1: 質問の送信（Backend → Frontend）

```bash
./scripts/msg.sh send \
    --from backend \
    --to frontend \
    --type question \
    --priority high \
    --title "APIレスポンス形式について" \
    --body "## 背景
ユーザー情報取得APIを実装中です。

## 質問内容
レスポンスのJSON形式は以下のどちらが望ましいですか？

## 選択肢
1. { \"user\": { \"id\": 1, \"name\": \"...\" } }
2. { \"id\": 1, \"name\": \"...\" }

## 緊急度
本日中に回答いただけると助かります。"
```

#### Step 2: 回答の送信（Frontend → Backend）

```bash
./scripts/msg.sh send \
    --from frontend \
    --to backend \
    --type answer \
    --priority high \
    --title "APIレスポンス形式について" \
    --body "## 回答
選択肢1の { \"user\": { ... } } 形式を推奨します。

## 理由
- 将来的に他のリソース（posts, commentsなど）も返す可能性がある
- ネストされた形式の方が拡張性が高い

## 追加情報
エラーレスポンスは { \"error\": { \"code\": ..., \"message\": ... } } で統一しましょう。" \
    --parent YYYYMMDD-001-q
```

### 検証項目

| 項目 | 確認方法 | 期待値 |
|------|---------|--------|
| 質問ファイル | `ls shared/questions/backend-to-frontend/` | 1ファイル |
| 回答ファイル | `ls shared/questions/answers/` | 1ファイル |

---

## 自動テストスクリプト

上記シナリオを自動実行するスクリプト: `scripts/test-e2e.sh`

---

## 更新履歴

- 2025-01-24: 初版作成
