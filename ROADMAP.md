# ROADMAP

agent-corpプロジェクトの開発ロードマップ。

---

## v0.1 - 基盤整備（Foundation）

プロジェクトの基本構造とエージェント定義を整備する。

- [x] ディレクトリ構成の作成
- [x] 役割別システムプロンプトの作成
  - [x] ceo.md
  - [x] pm.md
  - [x] engineers/frontend.md
  - [x] engineers/backend.md
  - [x] engineers/security.md
- [x] tmux起動スクリプトの作成

---

## v0.2 - 通信プロトコル（Communication）

エージェント間の通信方式を確立する。

- [x] エージェント間通信方式の設計
- [x] 共有ディレクトリ構成の決定
- [x] メッセージフォーマットの標準化（指示/報告/質問）
- [x] 基本的な通信スクリプトの実装

---

## v0.5 - 動作検証（Validation）

システム全体の動作を検証し、安定性を高める。

- [x] シンプルなタスクでのE2Eテスト
- [x] 複数エージェント協調動作の検証
- [x] エラーハンドリング・リカバリの実装
- [x] ログ収集・可視化

---

## v0.8 - ドキュメント整備（Documentation）

ユーザー向けドキュメントを充実させる。

- [x] セットアップガイド
- [x] ユースケース集
- [x] トラブルシューティング
- [x] コントリビューションガイド

---

## v1.0 - 正式リリース（Release）

安定版としてリリースし、拡張機能を提供する。

- [x] 安定版としてのリリース
  - [x] LICENSE (MIT)
  - [x] VERSION管理
- [x] 対応LLMエージェントの拡充
  - [x] config/agents.yaml（Claude, Aider, GPT CLI, Ollama, LM Studio, Cursor）
- [x] GUI監視ツール（オプション）
  - [x] tools/dashboard.html（ブラウザベースダッシュボード）
- [x] 組織構成カスタマイズ機能
  - [x] config/org-templates/default.yaml
  - [x] config/org-templates/minimal.yaml
  - [x] config/org-templates/large.yaml
