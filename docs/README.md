# agent-corp ドキュメント

> このドキュメントは、agent-corpプロジェクトの全体像を把握し、効率的に情報を探すためのインデックスです。

## 最初の1時間で読むべき3文書

1. **[../README.md](../README.md)** - プロジェクト概要とコンセプト（5分）
2. **[../CLAUDE.md](../CLAUDE.md)** - AI エージェント向け開発ガイド（10分）
3. **[design/README.md](./design/README.md)** - 設計思想の概要（15分）

---

## ドキュメントカテゴリ

### 1. Knowledge（実践的知識 - HOW）

**ディレクトリ**: `docs/knowledge/`

「どうやって実装するか」を説明するドキュメント。

| ドキュメント | 説明 | 優先度 |
|-------------|------|--------|
| `agent-prompts.md` | エージェントプロンプト設計ガイド | ⭐⭐⭐ 必読 |
| `tmux-integration.md` | tmux連携のベストプラクティス | ⭐⭐ 推奨 |
| `troubleshooting.md` | よくある問題と解決策 | ⭐ 問題発生時 |

→ 詳細は [knowledge/README.md](./knowledge/README.md) を参照

### 2. Design（設計思想 - WHY）

**ディレクトリ**: `docs/design/`

「なぜそう設計したか」を説明するドキュメント。

| ドキュメント | 説明 | 優先度 |
|-------------|------|--------|
| `org-hierarchy.md` | 組織階層設計（CEO/PM/Engineer） | ⭐⭐⭐ 必読 |
| `message-protocol.md` | エージェント間通信プロトコル | ⭐⭐⭐ 必読 |
| `shared-directory.md` | 共有ディレクトリ設計 | ⭐⭐ 推奨 |

→ 詳細は [design/README.md](./design/README.md) を参照

### 3. Flows（処理フロー - WHAT）

**ディレクトリ**: `docs/flows/`

「何が起こるか」を説明するドキュメント。機能ごとのシーケンス図と呼び出し順を記載。

| ドキュメント | 説明 |
|-------------|------|
| `task-assignment/` | タスク割り当てフロー |
| `agent-communication/` | エージェント間通信フロー |
| `error-recovery/` | エラー復旧フロー |

→ 詳細は [flows/README.md](./flows/README.md) を参照

### 4. Guide（ガイドライン）

**ディレクトリ**: `docs/guide/`

プロジェクトへの貢献方法やドキュメント作成ルール。

| ドキュメント | 説明 | 優先度 |
|-------------|------|--------|
| [setup.md](./guide/setup.md) | 環境構築・起動ガイド | ⭐⭐⭐ 必読 |
| [tutorial.md](./guide/tutorial.md) | チュートリアル（5種） | ⭐⭐⭐ 必読 |
| [rag-usage.md](./guide/rag-usage.md) | RAG機能利用ガイド | ⭐⭐ 推奨 |
| [configuration.md](./guide/configuration.md) | 設定カスタマイズ | ⭐⭐ 推奨 |
| [troubleshooting.md](./guide/troubleshooting.md) | トラブルシューティング | ⭐ 問題発生時 |
| [documentation.md](./guide/documentation.md) | ドキュメント作成ガイド | ⭐ 貢献時 |

### 5. Scripts（スクリプトリファレンス）

**ディレクトリ**: `scripts/`

| ドキュメント | 説明 |
|-------------|------|
| [scripts/README.md](../scripts/README.md) | 全スクリプトのリファレンス |

---

## 目的別ガイド

### 新規エージェントを追加したい

1. [design/org-hierarchy.md](./design/org-hierarchy.md) で役割分担を理解
2. [knowledge/agent-prompts.md](./knowledge/agent-prompts.md) でプロンプト設計を学ぶ
3. `prompts/` 配下に新規プロンプトファイルを作成

### 通信プロトコルを拡張したい

1. [design/message-protocol.md](./design/message-protocol.md) で現行プロトコルを理解
2. [flows/agent-communication/](./flows/agent-communication/) で通信フローを確認
3. 必要に応じて新規メッセージタイプを追加

### バグを修正したい

1. [flows/](./flows/) で該当機能のフローを確認
2. [guide/troubleshooting.md](./guide/troubleshooting.md) で既知の問題を確認
3. 該当ファイルを修正

---

## ドキュメント作成時の注意

新しいドキュメントを追加する際は、以下のガイドに従ってください：

- **[guide/documentation.md](./guide/documentation.md)** - ドキュメント作成ガイド

### カテゴリ選択の基準

| カテゴリ | 内容 | キーワード |
|---------|------|-----------|
| knowledge | 実践的な手順・方法 | 「〜する方法」「〜のやり方」 |
| design | 設計判断・理由 | 「なぜ〜」「〜の理由」 |
| flows | 処理の流れ・シーケンス | 「〜のフロー」「〜の順序」 |
| guide | 貢献ルール・ガイドライン | 「〜のルール」「〜の規約」 |

---

## 更新履歴

- 2026-01-25: RAG機能利用ガイド追加
- 2025-01-24: 初版作成
