# トラブルシューティング

agent-corpで発生しやすい問題と解決方法をまとめています。

---

## 起動・セッション関連

### tmuxセッションが起動しない

**症状:**
```
[ERROR] tmux がインストールされていません
```

**原因:** tmuxがインストールされていない

**解決策:**
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install tmux

# macOS
brew install tmux

# 確認
tmux -V
```

---

### セッションが既に存在するエラー

**症状:**
```
[ERROR] セッション 'agent-corp' は既に存在します
```

**原因:** 前回のセッションが残っている

**解決策:**
```bash
# 既存セッションにアタッチ
./scripts/start.sh attach

# または、セッションを終了してから再起動
./scripts/start.sh stop
./scripts/start.sh start
```

---

### セッションにアタッチできない

**症状:**
```
[ERROR] セッション 'agent-corp' は存在しません
```

**原因:** セッションが起動していない

**解決策:**
```bash
# セッションの状態を確認
./scripts/start.sh status

# セッションを起動
./scripts/start.sh start
```

---

## メッセージ関連

### メッセージが送信されない

**症状:**
```
[ERROR] 必須パラメータが不足しています
```

**原因:** 必須パラメータが指定されていない

**解決策:**
```bash
# 必須パラメータをすべて指定
./scripts/msg.sh send \
    --from human \
    --to ceo \
    --type requirement \
    --title "タイトル" \
    --body "本文"
```

**必須パラメータ:**
- `--from`: 送信元
- `--to`: 宛先
- `--type`: メッセージタイプ
- `--title`: タイトル
- `--body` または `--file`: 本文

---

### メッセージ一覧が表示されない

**症状:**
```
メッセージがありません
```

**原因:**
1. 指定したディレクトリにファイルがない
2. ディレクトリパスが間違っている

**解決策:**
```bash
# ディレクトリの存在確認
ls -la shared/requirements/

# 正しいパスで再実行
./scripts/msg.sh list --dir requirements

# 共有ディレクトリを再初期化
./scripts/init-shared.sh
```

---

### ステータス更新が反映されない

**症状:**
ステータスを更新したが、ファイルの内容が変わらない

**原因:** ファイルパスが間違っている

**解決策:**
```bash
# フルパスで指定
./scripts/msg.sh status \
    --file shared/requirements/20250124-001-req.md \
    --status in_progress

# または相対パスで指定
./scripts/msg.sh status \
    --file requirements/20250124-001-req.md \
    --status in_progress
```

---

## ヘルスチェック関連

### ディレクトリ構造エラー

**症状:**
```
[WARN] ディレクトリが見つかりません: tasks/frontend
```

**原因:** 共有ディレクトリが正しく初期化されていない

**解決策:**
```bash
# 自動修復
./scripts/health.sh fix

# または手動で初期化
./scripts/init-shared.sh
```

---

### 古いpendingメッセージ警告

**症状:**
```
[WARN] 古いpendingメッセージ: 20250120-001-req.md (5760分前)
```

**原因:** 長時間処理されていないメッセージがある

**解決策:**
```bash
# メッセージの内容を確認
./scripts/msg.sh read requirements/20250120-001-req.md

# ステータスを更新（処理中なら）
./scripts/msg.sh status --file requirements/20250120-001-req.md --status in_progress

# または完了にする
./scripts/msg.sh status --file requirements/20250120-001-req.md --status completed

# 不要なら削除（またはアーカイブ）
./scripts/health.sh cleanup --days 0
```

---

### ブロック中メッセージアラート

**症状:**
```
[ERROR] 長時間ブロック中: 20250123-005-task.md (180分前)
```

**原因:** タスクがブロックされたまま放置されている

**解決策:**
```bash
# ブロック理由を確認
./scripts/msg.sh read tasks/backend/20250123-005-task.md

# 対話的に復旧
./scripts/health.sh recover

# または手動でステータスを変更
./scripts/msg.sh status --file tasks/backend/20250123-005-task.md --status pending
```

---

## LLMエージェント関連

### Claude Codeが起動しない

**症状:**
```
claude: command not found
```

**原因:** Claude Codeがインストールされていない、またはPATHが通っていない

**解決策:**
```bash
# インストール
npm install -g @anthropic-ai/claude-code

# PATHを確認
which claude

# npmグローバルパスを追加
export PATH="$PATH:$(npm config get prefix)/bin"
```

---

### APIキーエラー

**症状:**
```
Error: Invalid API key
```

**原因:** APIキーが設定されていない、または無効

**解決策:**
```bash
# Claude Code
export ANTHROPIC_API_KEY="sk-ant-..."

# Aider (OpenAI)
export OPENAI_API_KEY="sk-..."

# 永続化（~/.bashrc または ~/.zshrc に追加）
echo 'export ANTHROPIC_API_KEY="sk-ant-..."' >> ~/.bashrc
source ~/.bashrc
```

---

### エージェントが応答しない

**症状:**
エージェントにメッセージを送っても処理が進まない

**原因:**
1. エージェントがメッセージを監視していない
2. プロンプトの指示が不明確

**解決策:**
```bash
# 手動でメッセージを確認させる
# エージェントのtmuxペインで以下を入力
cat shared/tasks/frontend/20250124-001-task.md

# 監視スクリプトを使用
./scripts/msg.sh watch --dir tasks/frontend
```

---

### 新しい依頼がいつまでも着手されない

**症状:**
新しいrequirementを送信したが、エージェントが古いタスクを処理し続けて新しい依頼に着手しない

**原因:**
エージェントはファイルを**順番に**処理するため、過去の未処理タスクが大量に残っていると、新しい依頼にたどり着くまでに長時間かかります。各エージェントは`shared/.processed/`ディレクトリのMD5ハッシュマーカーで処理済みかどうかを判定しており、マーカーがないファイルをすべて処理しようとします。

**典型的なケース:**
- 過去のプロジェクトで生成された大量のタスク・レポートが残っている
- 途中で中断した依頼のタスクが未処理のまま残っている
- CEOやPMが古いレポートを全件読み直してしまい、トークンを浪費する

**解決策:**

```bash
# Step 1: まず対象件数を確認（ドライラン）
./scripts/msg.sh reset --dry-run

# Step 2: 全未処理ファイルを処理済みにマーク
./scripts/msg.sh reset

# Step 3: エージェントを再起動
./scripts/start.sh stop
./scripts/start.sh start

# Step 4: 新しい依頼を送信
./scripts/msg.sh send --from human --to ceo --type requirement \
    --title "新しい依頼" --body "..."
```

**補足:**
- `reset`コマンドはファイルを削除しません。`shared/.processed/`にハッシュマーカーを作成するだけです
- リセット後、各エージェントは新しいファイルのみを処理対象として認識します
- ダッシュボード（`./scripts/dashboard.sh`）の「Pending Queue」セクションで未処理タスク数を確認できます

---

### CEOやPMが古いコンテキストに引きずられる

**症状:**
新しい依頼を送ったのに、CEOが「QA完了を待つ」などと古いレポート内容に基づいた判断をしてしまう

**原因:**
CEOやPMは起動時にreportsディレクトリも監視しており、古いレポートを読み込むことで過去のコンテキストに影響されます。

**解決策:**
1. `./scripts/msg.sh reset` で全ファイルを処理済みにマーク
2. 新しい依頼には**明確な指示**を含める（例: 「QAは完了済み。即座に実装を開始せよ」）
3. `--priority critical` で優先度を上げる

---

## パフォーマンス関連

### ディスク容量警告

**症状:**
```
[WARN] ディスク容量が警告レベル: 85%
```

**原因:** ログやアーカイブが蓄積している

**解決策:**
```bash
# 古いファイルをアーカイブ
./scripts/health.sh cleanup --days 7

# ログの確認と削除
du -sh shared/logs/
rm -rf shared/logs/*.log

# アーカイブの削除（必要に応じて）
rm -rf shared/archive/202501*
```

---

### 監視スクリプトが重い

**症状:**
`monitor.sh dashboard` がCPUを消費する

**原因:** 更新間隔が短すぎる

**解決策:**
```bash
# 更新間隔を長くする
./scripts/monitor.sh dashboard --refresh 5  # 5秒間隔

# または静的な状態確認を使用
./scripts/monitor.sh status
```

---

## よくある質問

### Q: 複数のプロジェクトで使える？

**A:** はい。プロジェクトごとにagent-corpをクローンするか、`SHARED_DIR`環境変数で共有ディレクトリを分離してください。

```bash
# プロジェクトA
SHARED_DIR=./shared-project-a ./scripts/start.sh start

# プロジェクトB
SHARED_DIR=./shared-project-b ./scripts/start.sh start
```

---

### Q: カスタムエージェントを追加できる？

**A:** はい。`prompts/`に新しいプロンプトファイルを作成し、`scripts/start.sh`を修正して新しいウィンドウを追加してください。

---

### Q: メッセージを手動で編集できる？

**A:** はい。`shared/`配下のMarkdownファイルを直接編集できます。ただし、YAML Frontmatterの形式を維持してください。

---

### Q: 過去のメッセージを復元できる？

**A:** `shared/archive/`にアーカイブされたファイルを元のディレクトリに戻すことで復元できます。

```bash
# アーカイブから復元
mv shared/archive/20250124/20250120-001-req.md shared/requirements/
```

---

## サポート

問題が解決しない場合：

1. **ヘルスチェックを実行:**
   ```bash
   ./scripts/health.sh check --verbose
   ```

2. **ログを確認:**
   ```bash
   cat shared/logs/$(date +%Y%m%d).log
   ```

3. **E2Eテストを実行:**
   ```bash
   ./scripts/test-e2e.sh
   ```

4. **GitHubでIssueを作成:**
   https://github.com/kenimo49/agent-corp/issues

---

## 関連ドキュメント

- [セットアップガイド](./setup.md)
- [ユースケース集](./usecases.md)
- [ヘルスチェックスクリプト](../../scripts/health.sh)

---

## 更新履歴

- 2025-01-24: 初版作成
