# 共有ディレクトリ設計

## 概要

agent-corpにおけるエージェント間のファイル共有ディレクトリの設計。`shared/`ディレクトリを中央ハブとして、すべてのエージェントがメッセージとファイルを交換する。

## 背景

### 設計方針

1. **単一の共有ポイント**: `shared/`ディレクトリに集約
2. **明確なパス規則**: 送信元・宛先が一目でわかる構造
3. **読み取り/書き込み権限**: 役割に基づくアクセス制御
4. **履歴の保持**: 削除せずアーカイブ

---

## ディレクトリ構造

```
shared/
├── requirements/           # [Human → CEO] 要件定義
├── instructions/           # [CEO → PM] 戦略的指示
│   └── pm/
├── tasks/                  # [PM → Engineers] 具体的タスク
│   ├── frontend/
│   ├── backend/
│   └── security/
├── reports/                # [下位 → 上位] 進捗報告
│   ├── engineers/
│   │   ├── frontend/
│   │   ├── backend/
│   │   └── security/
│   ├── pm/
│   └── human/
├── questions/              # [任意] 質問・回答
│   ├── ceo-to-pm/
│   ├── pm-to-frontend/
│   ├── pm-to-backend/
│   ├── pm-to-security/
│   ├── frontend-to-backend/
│   ├── backend-to-frontend/
│   ├── backend-to-security/
│   ├── security-to-backend/
│   └── answers/
├── specs/                  # [共有] 仕様書
│   ├── api/
│   ├── design/
│   └── requirements/
├── artifacts/              # [共有] 成果物
│   ├── code/
│   ├── docs/
│   └── reviews/
├── logs/                   # [システム] ログ
│   └── {date}/
└── archive/                # [システム] アーカイブ
    └── {date}/
```

---

## アクセス権限マトリクス

### 書き込み権限

| ディレクトリ | Human | CEO | PM | Frontend | Backend | Security |
|-------------|-------|-----|----|---------:|--------:|---------:|
| requirements/ | ✅ | - | - | - | - | - |
| instructions/pm/ | - | ✅ | - | - | - | - |
| tasks/frontend/ | - | - | ✅ | - | - | - |
| tasks/backend/ | - | - | ✅ | - | - | - |
| tasks/security/ | - | - | ✅ | - | - | - |
| reports/engineers/frontend/ | - | - | - | ✅ | - | - |
| reports/engineers/backend/ | - | - | - | - | ✅ | - |
| reports/engineers/security/ | - | - | - | - | - | ✅ |
| reports/pm/ | - | - | ✅ | - | - | - |
| reports/human/ | - | ✅ | - | - | - | - |
| specs/ | - | - | ✅ | ✅ | ✅ | ✅ |
| artifacts/ | - | - | ✅ | ✅ | ✅ | ✅ |

### 読み取り権限

| ディレクトリ | Human | CEO | PM | Frontend | Backend | Security |
|-------------|-------|-----|----|---------:|--------:|---------:|
| requirements/ | ✅ | ✅ | - | - | - | - |
| instructions/pm/ | - | ✅ | ✅ | - | - | - |
| tasks/frontend/ | - | - | ✅ | ✅ | - | - |
| tasks/backend/ | - | - | ✅ | - | ✅ | - |
| tasks/security/ | - | - | ✅ | - | - | ✅ |
| reports/* | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| specs/ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| artifacts/ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

---

## ファイルライフサイクル

### 1. 作成

```
1. エージェントがファイルを作成
2. ステータス: pending
3. ファイル名: {date}-{seq}-{type}.md
```

### 2. 処理中

```
1. 宛先エージェントがファイルを検出
2. ステータス更新: in_progress
3. 処理開始
```

### 3. 完了

```
1. 処理完了
2. ステータス更新: completed
3. 報告ファイル作成
```

### 4. アーカイブ

```
1. 一定期間経過（7日など）
2. archive/{date}/ に移動
3. 元のディレクトリから削除
```

---

## 初期化スクリプト

`scripts/init-shared.sh`:

```bash
#!/bin/bash

# 共有ディレクトリの初期化

SHARED_DIR="${1:-./shared}"

# ディレクトリ作成
mkdir -p "$SHARED_DIR"/{requirements,instructions/pm}
mkdir -p "$SHARED_DIR"/tasks/{frontend,backend,security}
mkdir -p "$SHARED_DIR"/reports/{human,pm}
mkdir -p "$SHARED_DIR"/reports/engineers/{frontend,backend,security}
mkdir -p "$SHARED_DIR"/questions/{answers}
mkdir -p "$SHARED_DIR"/specs/{api,design,requirements}
mkdir -p "$SHARED_DIR"/artifacts/{code,docs,reviews}
mkdir -p "$SHARED_DIR"/{logs,archive}

# .gitkeep作成（空ディレクトリをgitで管理）
find "$SHARED_DIR" -type d -empty -exec touch {}/.gitkeep \;

echo "共有ディレクトリを初期化しました: $SHARED_DIR"
```

---

## 監視・ポーリング

### inotifywait使用（Linux）

```bash
# リアルタイム監視
inotifywait -m -r -e create,modify shared/tasks/frontend/ |
while read path action file; do
    echo "新着タスク: $file"
    # 処理開始
done
```

### ポーリングスクリプト

```bash
#!/bin/bash
# poll.sh - 新着メッセージのポーリング

WATCH_DIR="$1"
LAST_CHECK=".last_check_$(basename $WATCH_DIR)"

# 新着ファイルの検出
if [ -f "$LAST_CHECK" ]; then
    find "$WATCH_DIR" -name "*.md" -newer "$LAST_CHECK" -type f
else
    find "$WATCH_DIR" -name "*.md" -type f
fi

# チェックポイント更新
touch "$LAST_CHECK"
```

---

## 排他制御

### ロックファイル方式

```bash
# ファイル書き込み時
LOCK_FILE="${FILE}.lock"

# ロック取得
while ! mkdir "$LOCK_FILE" 2>/dev/null; do
    sleep 0.1
done

# 書き込み処理
echo "content" > "$FILE"

# ロック解放
rmdir "$LOCK_FILE"
```

### ステータスによる制御

- `pending`: 未処理（書き込み可）
- `in_progress`: 処理中（書き込み禁止）
- `completed`: 完了（読み取りのみ）

---

## クリーンアップポリシー

### 自動アーカイブ

```bash
#!/bin/bash
# archive.sh - 古いファイルのアーカイブ

DAYS=7
DATE=$(date +%Y%m%d)
ARCHIVE_DIR="shared/archive/$DATE"

mkdir -p "$ARCHIVE_DIR"

# 7日以上前のcompletedファイルを移動
find shared/{requirements,instructions,tasks,reports} \
    -name "*.md" \
    -mtime +$DAYS \
    -exec grep -l "status: completed" {} \; |
while read file; do
    mv "$file" "$ARCHIVE_DIR/"
done
```

### 保持期間

| カテゴリ | アクティブ保持 | アーカイブ保持 |
|---------|--------------|--------------|
| requirements | 30日 | 1年 |
| instructions | 14日 | 6ヶ月 |
| tasks | 7日 | 3ヶ月 |
| reports | 14日 | 6ヶ月 |
| questions | 7日 | 1ヶ月 |

---

## トラブルシューティング

### 問題: ファイルの競合

**症状**: 複数エージェントが同時にファイルを更新

**解決策**:
1. ロックファイルの使用
2. 追記専用の運用（上書きしない）
3. ファイル名にタイムスタンプを含める

### 問題: ディスク容量不足

**症状**: 共有ディレクトリが肥大化

**解決策**:
1. 定期的なアーカイブスクリプトの実行
2. 古いログの圧縮・削除
3. 監視アラートの設定

### 問題: メッセージの見落とし

**症状**: 新着メッセージが処理されない

**解決策**:
1. ポーリング間隔の短縮
2. inotifywaitによるリアルタイム監視
3. 未処理ファイルの定期レポート

---

## 関連ドキュメント

- [docs/design/message-protocol.md](./message-protocol.md) - メッセージプロトコル設計
- [docs/knowledge/troubleshooting.md](../knowledge/troubleshooting.md) - トラブルシューティング

---

## 更新履歴

- 2025-01-24: 初版作成
