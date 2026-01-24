# メッセージテンプレート

> このテンプレートは、エージェント間のメッセージを作成するための標準フォーマットです。
> コピーして適切なディレクトリに配置し、<>内を実際の値に置き換えてください。

## ファイルの配置場所

| メッセージタイプ | 送信元 → 宛先 | ディレクトリ |
|----------------|--------------|-------------|
| requirement | Human → CEO | `shared/requirements/` |
| instruction | CEO → PM | `shared/instructions/pm/` |
| task | PM → Engineer | `shared/tasks/{engineer}/` |
| report | Engineer → PM | `shared/reports/engineers/{engineer}/` |
| report | PM → CEO | `shared/reports/pm/` |
| report | CEO → Human | `shared/reports/human/` |
| question | Any → Any | `shared/questions/{from}-to-{to}/` |
| answer | Any → Any | `shared/questions/answers/` |

詳細は [docs/design/message-protocol.md](../design/message-protocol.md) を参照してください。

---

## 共通ヘッダー

すべてのメッセージに以下のYAML Frontmatterを含めます：

```yaml
---
id: <ULID形式のID>
from: <送信者: human|ceo|pm|frontend|backend|security>
to: <宛先: ceo|pm|frontend|backend|security|human>
type: <メッセージタイプ: requirement|instruction|task|report|question|answer>
priority: <優先度: critical|high|medium|low>
status: <ステータス: pending|in_progress|completed|blocked>
created_at: <ISO 8601形式の日時>
updated_at: <ISO 8601形式の日時>
parent_id: <親メッセージID（あれば）>
---
```

---

## テンプレート一覧

### 1. 要件（Requirement）

```markdown
---
id: <ID>
from: human
to: ceo
type: requirement
priority: high
status: pending
created_at: <timestamp>
updated_at: <timestamp>
---

# 要件: <タイトル>

## 概要
<何を実現したいか>

## 背景
<なぜ必要か>

## 期待する成果
- <成果1>
- <成果2>

## 制約条件
- <制約1>
- <制約2>

## 優先順位
<最も重要な点>

## 備考
<追加情報>
```

### 2. 指示（Instruction）

```markdown
---
id: <ID>
from: ceo
to: pm
type: instruction
priority: high
status: pending
created_at: <timestamp>
updated_at: <timestamp>
parent_id: <requirement-id>
---

# 指示: <タイトル>

## ゴール
<達成すべき目標>

## コンテキスト
<背景情報、判断の理由>

## 成功基準
- [ ] <基準1>
- [ ] <基準2>

## 制約条件
- <制約1>
- <制約2>

## 推奨アプローチ
<技術的方向性の提案>

## 優先順位
<タスク間の優先順位>
```

### 3. タスク（Task）

```markdown
---
id: <ID>
from: pm
to: <frontend|backend|security>
type: task
priority: high
status: pending
created_at: <timestamp>
updated_at: <timestamp>
parent_id: <instruction-id>
---

# タスク: <タイトル>

## 説明
<何を実装するか>

## 完了条件
- [ ] <条件1>
- [ ] <条件2>

## 技術要件
- <要件1>
- <要件2>

## 依存関係
- 前提: <他タスクID>
- ブロック: <このタスクを待つタスク>

## 参考資料
- <リンク1>
- <リンク2>

## 備考
<追加情報>
```

### 4. 報告（Report）

```markdown
---
id: <ID>
from: <frontend|backend|security|pm|ceo>
to: <pm|ceo|human>
type: report
priority: medium
status: completed
created_at: <timestamp>
updated_at: <timestamp>
parent_id: <task-id>
---

# 報告: <タイトル>

## ステータス
<completed|in_progress|blocked>

## 完了項目
- [x] <完了した項目1>
- [x] <完了した項目2>

## 残作業
- [ ] <残っている項目>

## 成果物
- <ファイルパス1>: <説明>
- <ファイルパス2>: <説明>

## 課題・懸念
- <課題1>

## 次のステップ
- <次のアクション>

## 備考
<追加情報>
```

### 5. 質問（Question）

```markdown
---
id: <ID>
from: <送信元>
to: <宛先>
type: question
priority: high
status: pending
created_at: <timestamp>
updated_at: <timestamp>
context_id: <関連タスクID>
---

# 質問: <タイトル>

## 背景
<質問の背景>

## 質問内容
<具体的な質問>

## 選択肢（あれば）
1. <選択肢A>
2. <選択肢B>

## 緊急度
<なぜ急ぎか、いつまでに回答が必要か>
```

### 6. 回答（Answer）

```markdown
---
id: <ID>
from: <回答者>
to: <質問者>
type: answer
priority: high
status: completed
created_at: <timestamp>
updated_at: <timestamp>
parent_id: <question-id>
---

# 回答: <質問タイトル>

## 回答
<回答内容>

## 理由
<回答の根拠>

## 追加情報
<参考情報>
```

---

## CLIでの作成

`scripts/msg.sh` を使用してメッセージを作成できます：

```bash
# 要件を送信
./scripts/msg.sh send \
    --from human \
    --to ceo \
    --type requirement \
    --title "ログイン機能の実装" \
    --body "ユーザー認証機能を追加してください"

# タスクを送信
./scripts/msg.sh send \
    --from pm \
    --to frontend \
    --type task \
    --priority high \
    --title "ログインフォームの実装" \
    --file task-description.md \
    --parent 20250124-001-inst
```

---

## 更新履歴

- 2025-01-24: 初版作成
