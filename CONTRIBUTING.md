# コントリビューションガイド

agent-corpへの貢献に興味を持っていただきありがとうございます。このガイドでは、プロジェクトへの貢献方法を説明します。

---

## 貢献の種類

### 1. バグ報告

バグを見つけた場合は、[GitHub Issues](https://github.com/kenimo49/agent-corp/issues)で報告してください。

**報告時に含める情報:**
- 環境（OS、tmuxバージョン、LLMエージェント）
- 再現手順
- 期待される動作
- 実際の動作
- エラーメッセージ（あれば）

**テンプレート:**
```markdown
## 環境
- OS: Ubuntu 22.04 / macOS 14.0 / WSL2
- tmux: 3.3
- LLMエージェント: Claude Code v1.0.0

## 再現手順
1. `./scripts/start.sh start` を実行
2. ...

## 期待される動作
...

## 実際の動作
...

## エラーメッセージ
```
[ERROR] ...
```
```

---

### 2. 機能リクエスト

新機能のアイデアがある場合は、Issueで提案してください。

**提案時に含める情報:**
- 機能の概要
- ユースケース
- 期待される動作
- （オプション）実装のアイデア

---

### 3. コード貢献

#### 開発環境のセットアップ

```bash
# リポジトリをフォーク＆クローン
git clone https://github.com/YOUR_USERNAME/agent-corp.git
cd agent-corp

# 開発ブランチを作成
git checkout -b feature/your-feature-name

# 共有ディレクトリを初期化
./scripts/init-shared.sh
```

#### コーディング規約

**Bashスクリプト:**
- ShellCheckでリントを通す
- `set -e` でエラー時に停止
- 関数にはコメントを付ける
- 変数名は`snake_case`

```bash
#!/bin/bash
set -e

# 説明: メッセージを送信する
# 引数: $1 - 送信元, $2 - 宛先
send_message() {
    local from="$1"
    local to="$2"
    # ...
}
```

**Markdownドキュメント:**
- 見出しは適切な階層で
- コードブロックには言語を指定
- 相対リンクを使用

---

#### プルリクエストの作成

1. **テストを実行:**
   ```bash
   ./scripts/test-e2e.sh
   ./scripts/health.sh check
   ```

2. **変更をコミット:**
   ```bash
   git add .
   git commit -m "feat: 新機能の説明"
   ```

   **コミットメッセージの形式:**
   ```
   <type>: <description>

   [optional body]

   [optional footer]
   ```

   **type:**
   - `feat`: 新機能
   - `fix`: バグ修正
   - `docs`: ドキュメントのみ
   - `style`: コードスタイル（動作に影響しない）
   - `refactor`: リファクタリング
   - `test`: テストの追加・修正
   - `chore`: ビルド、設定など

3. **プッシュ:**
   ```bash
   git push origin feature/your-feature-name
   ```

4. **プルリクエストを作成:**
   - タイトル: `feat: 新機能の説明`
   - 本文: 変更内容、テスト結果、関連Issue

---

### 4. ドキュメント貢献

ドキュメントの改善も歓迎します。

**対象:**
- 誤字・脱字の修正
- 説明の改善
- 新しいユースケースの追加
- 翻訳

**ドキュメントの場所:**
```
docs/
├── README.md          # インデックス
├── guide/             # ガイド
│   ├── setup.md
│   ├── usecases.md
│   ├── troubleshooting.md
│   └── documentation.md
├── design/            # 設計ドキュメント
├── knowledge/         # ナレッジベース
└── flows/             # 処理フロー
```

---

## 開発ワークフロー

### ブランチ戦略

```
main
├── feature/xxx    # 新機能
├── fix/xxx        # バグ修正
├── docs/xxx       # ドキュメント
└── refactor/xxx   # リファクタリング
```

### レビュープロセス

1. PRを作成
2. 自動テスト（CI）が実行される
3. メンテナーがレビュー
4. フィードバックに対応
5. 承認後にマージ

---

## ディレクトリ構成

```
agent-corp/
├── CLAUDE.md              # AIエージェント向けガイド
├── CONTRIBUTING.md        # ← このファイル
├── README.md              # プロジェクト概要
├── ROADMAP.md             # 開発ロードマップ
├── prompts/               # システムプロンプト
│   ├── ceo.md
│   ├── pm.md
│   └── engineers/
├── scripts/               # 管理スクリプト
│   ├── start.sh           # セッション起動
│   ├── msg.sh             # メッセージ管理
│   ├── monitor.sh         # 監視・ログ
│   ├── health.sh          # ヘルスチェック
│   ├── init-shared.sh     # 初期化
│   └── test-e2e.sh        # E2Eテスト
├── shared/                # エージェント間共有
├── docs/                  # ドキュメント
└── tests/                 # テスト
```

---

## 新機能の追加ガイド

### 新しいエージェントの追加

1. **プロンプトファイルを作成:**
   ```
   prompts/engineers/devops.md
   ```

2. **start.shを更新:**
   - 新しいウィンドウまたはペインを追加

3. **共有ディレクトリを追加:**
   ```bash
   mkdir -p shared/tasks/devops
   mkdir -p shared/reports/engineers/devops
   ```

4. **ドキュメントを更新:**
   - CLAUDE.md
   - docs/design/org-hierarchy.md

### 新しいメッセージタイプの追加

1. **設計ドキュメントを更新:**
   - docs/design/message-protocol.md

2. **msg.shを更新:**
   - `get_message_dir()` 関数に新しいタイプを追加

3. **テンプレートを追加:**
   - docs/_templates/message.md

4. **テストを追加:**
   - tests/e2e-scenario.md

### 新しいスクリプトの追加

1. **スクリプトを作成:**
   ```bash
   touch scripts/new-script.sh
   chmod +x scripts/new-script.sh
   ```

2. **ヘッダーを追加:**
   ```bash
   #!/bin/bash
   # agent-corp 新しいスクリプト
   # 説明...
   ```

3. **テストを追加:**
   - test-e2e.sh に新しいテストを追加

4. **ドキュメントを更新:**
   - README.md
   - docs/guide/setup.md

---

## 行動規範

- 敬意を持ってコミュニケーションする
- 建設的なフィードバックを心がける
- 多様性を尊重する
- 初心者を歓迎する

---

## 質問・サポート

- **GitHub Issues**: バグ報告、機能リクエスト
- **GitHub Discussions**: 質問、議論

---

## ライセンス

このプロジェクトはMITライセンスの下で公開されています。貢献していただいたコードも同じライセンスが適用されます。

---

## 謝辞

agent-corpに貢献してくださるすべての方に感謝します。

---

## 更新履歴

- 2025-01-24: 初版作成
