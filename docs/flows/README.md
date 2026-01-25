# 処理フロー（Flows）

## 概要

このディレクトリには、agent-corpにおける各機能の処理フローをまとめています。

処理フローは「**何が起こるか（WHAT）**」を説明するドキュメントで、以下の情報を含みます：
- エントリーポイント（フローの開始点）
- 呼び出し順序（処理の流れ）
- 関連ファイル
- 観測点（ログ、状態ファイル）
- Mermaidシーケンス図

## このディレクトリの目的

- 複数エージェント間の処理フローを体系的に理解できるようにする
- 指示・報告・質問のメッセージフローを明確化する
- 新規開発者がシステム全体の動作を素早く把握できるようにする

## ディレクトリ構成

```
docs/flows/
├── README.md                      # ← 今読んでいるファイル
├── task-assignment/               # タスク割り当てフロー
│   ├── README.md
│   ├── feature-ceo-to-pm.md      # CEO → PM への指示フロー
│   └── feature-pm-to-engineer.md # PM → Engineer への割り当てフロー
├── agent-communication/           # エージェント間通信フロー
│   ├── README.md
│   ├── feature-instruction.md    # 指示メッセージフロー
│   ├── feature-report.md         # 報告メッセージフロー
│   └── feature-question.md       # 質問メッセージフロー
└── error-recovery/               # エラー復旧フロー
    ├── README.md
    └── feature-agent-restart.md  # エージェント再起動フロー
```

## フロー一覧

### 1. タスク割り当て（Task Assignment）

CEO → PM → Engineer の階層的なタスク割り当てフロー。

| ドキュメント | 状態 | 説明 |
|-------------|------|------|
| [requirement-to-task.md](./task-assignment/requirement-to-task.md) | ✅ | 要件からタスクへの変換フロー |

### 2. エージェント間通信（Agent Communication）

エージェント間のメッセージ交換フロー。

| ドキュメント | 状態 | 説明 |
|-------------|------|------|
| [report-flow.md](./agent-communication/report-flow.md) | ✅ | 下位→上位への報告フロー |

### 3. エラー復旧（Error Recovery）

エラー発生時の復旧フロー。

| ドキュメント | 状態 | 説明 |
|-------------|------|------|
| [agent-restart.md](./error-recovery/agent-restart.md) | ✅ | エージェント再起動フロー |

---

## 典型的な処理フロー例

### 例1: claude-loopモード（自動監視）のフロー

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

**処理の流れ:**
1. 人間が `msg.sh` で要件を `shared/requirements/` に作成
2. CEO（agent-loop.sh ceo）が要件を検出、PMへの指示を作成
3. PM（agent-loop.sh pm）が指示を検出、タスクに分解
4. Engineers（agent-loop.sh frontend/backend/security）がタスクを実行、報告作成
5. PMがエンジニア報告を集約、CEOへ報告
6. CEOが最終報告を `shared/reports/human/` に作成

### 例2: 従来フロー（手動）

```
1. 人間がCEOに要件を伝える
   ↓
2. CEOがビジョンを分析し、戦略的指示を作成
   ↓
3. CEOがPMに指示を送信（共有ディレクトリ経由）
   ↓
4. PMがタスクを分解し、Engineer別に作業を割り当て
   ↓
5. Engineerが実装を行い、完了報告をPMに送信
   ↓
6. PMがレビューを実施し、進捗報告をCEOに送信
   ↓
7. CEOが人間に最終報告を行う
```

### 例2: エラー復旧の流れ

```
1. Engineerがエラーで停止
   ↓
2. PMがエラーを検知（共有ディレクトリの状態ファイル監視）
   ↓
3. PMがエージェント再起動を指示
   ↓
4. スクリプトがtmuxペインでエージェントを再起動
   ↓
5. Engineerが前回のタスクを再開
```

---

## 新しいフローを追加する

1. [_templates/flow.md](../_templates/flow.md) をコピー
2. 適切なディレクトリに配置
3. テンプレートの `<>` を実際の値に置き換え
4. このREADME.mdのフロー一覧に追加

---

## 関連ドキュメント

- [docs/design/message-protocol.md](../design/message-protocol.md) - メッセージプロトコル設計
- [docs/design/shared-directory.md](../design/shared-directory.md) - 共有ディレクトリ設計
- [docs/guide/troubleshooting.md](../guide/troubleshooting.md) - トラブルシューティング

---

## 更新履歴

- 2025-01-24: 初版作成
