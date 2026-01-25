# 実践的知識（Knowledge）

## 概要

このディレクトリには、agent-corpにおける実践的な知識やベストプラクティスをまとめています。

実践的知識は「**どうやって実装するか（HOW）**」を説明するドキュメントで、以下の情報を含みます：
- 具体的な実装手順
- ベストプラクティス
- よくある問題と解決策

## このディレクトリの目的

- 新規開発者が素早くシステムを理解し、実装を始められるようにする
- よくある問題の解決策を共有し、同じ問題に繰り返し悩まないようにする
- ベストプラクティスを標準化し、コードの品質を維持する

## ドキュメント一覧

### 優先度別

| 優先度 | ドキュメント | 状態 | 説明 |
|--------|-------------|------|------|
| ⭐⭐⭐ 必読 | [agent-prompts.md](./agent-prompts.md) | ✅ | エージェントプロンプト設計ガイド |
| ⭐⭐⭐ 必読 | [token-consumption.md](./token-consumption.md) | ✅ | トークン消費の仕組みとコスト最適化 |
| ⭐⭐ 推奨 | [rag-integration.md](./rag-integration.md) | ✅ | RAG機能（プロジェクトコンテキスト自動注入） |
| ⭐⭐ 推奨 | [tmux-integration.md](./tmux-integration.md) | ✅ | tmux連携のベストプラクティス |
| ⭐ 問題発生時 | [../guide/troubleshooting.md](../guide/troubleshooting.md) | ✅ | よくある問題と解決策 |

### カテゴリ別

#### エージェント設計

| ドキュメント | 説明 |
|-------------|------|
| [agent-prompts.md](./agent-prompts.md) | エージェントプロンプト設計ガイド |
| [llm-cli-commands.md](./llm-cli-commands.md) | LLM CLIコマンド差異（Claude -p vs Codex exec） |
| [rag-integration.md](./rag-integration.md) | RAG機能（プロジェクトコンテキスト自動注入） |

#### コスト・パフォーマンス

| ドキュメント | 説明 |
|-------------|------|
| [token-consumption.md](./token-consumption.md) | トークン消費の仕組みとコスト最適化 |

#### 環境構築

| ドキュメント | 説明 |
|-------------|------|
| [tmux-integration.md](./tmux-integration.md) | tmux連携のベストプラクティス |
| [../guide/setup.md](../guide/setup.md) | 環境セットアップガイド |

#### トラブルシューティング

→ [docs/guide/troubleshooting.md](../guide/troubleshooting.md) を参照

---

## ユースケース別ガイド

### 新しいエージェントを追加したい

1. **[agent-prompts.md](./agent-prompts.md)** を読んでプロンプト設計を学ぶ
2. **[../design/org-hierarchy.md](../design/org-hierarchy.md)** で役割分担を確認
3. `prompts/` 配下に新規プロンプトファイルを作成

### tmuxでエージェントを起動したい

1. **[tmux-integration.md](./tmux-integration.md)** を読んでtmux連携を理解
2. `scripts/` 配下の起動スクリプトを参照
3. 必要に応じてカスタマイズ

### エラーが発生した

1. **[troubleshooting.md](../guide/troubleshooting.md)** で既知の問題を確認
2. **[../flows/error-recovery/](../flows/error-recovery/)** でエラー復旧フローを確認
3. 解決しない場合は新しい問題としてドキュメントに追加

---

## ドキュメント作成ガイドライン

新しいknowledgeドキュメントを追加する際は、以下の構成に従ってください：

```markdown
# タイトル

## 概要
このドキュメントの目的を1-2文で説明

## 前提条件
読者が持っているべき知識や環境

## 手順
1. ステップ1
2. ステップ2
...

## ベストプラクティス
- 推奨事項1
- 推奨事項2

## よくある問題
### 問題1
**症状**: ...
**原因**: ...
**解決策**: ...

## 関連ドキュメント
- [リンク1](./xxx.md)
- [リンク2](./yyy.md)
```

---

## 関連ドキュメント

- [docs/design/README.md](../design/README.md) - 設計思想（WHY）
- [docs/flows/README.md](../flows/README.md) - 処理フロー（WHAT）
- [docs/guide/documentation.md](../guide/documentation.md) - ドキュメント作成ガイド

---

## 更新履歴

- 2026-01-25: rag-integration.md追加（RAGによるプロジェクトコンテキスト自動注入）
- 2026-01-25: llm-cli-commands.md追加（Claude/Codexコマンド差異）
- 2025-01-24: 初版作成
