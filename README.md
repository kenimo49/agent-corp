# agent-corp

複数のAIエージェントを階層構造で連携させ、自律的に開発を行う「AI組織」を構築するためのフレームワーク。

## TL;DR

```bash
# 起動
./scripts/start.sh start

# 要件を送信（別ターミナル）
./scripts/msg.sh send --from human --to ceo --type requirement \
    --title "機能追加" --body "ログイン機能を実装してください"

# 4分割画面で進行確認
./scripts/start.sh attach   # → Ctrl+b 4

# 最終報告を確認
cat shared/reports/human/*.md
```

## コンセプト

```
┌─────────────┐
│   社長 AI   │  ← ビジョン分析・戦略的指示
└──────┬──────┘
       │
┌──────▼──────┐
│   PM AI     │  ← タスク分解・進捗管理・レビュー
└──────┬──────┘
       │
┌──────┴──────────────────────┐
│             │               │
▼             ▼               ▼
┌─────────┐ ┌─────────┐ ┌─────────┐
│Engineer │ │Engineer │ │Engineer │
│   AI    │ │   AI    │ │   AI    │
│(Frontend)│ │(Backend)│ │(Security)│
└─────────┘ └─────────┘ └─────────┘
```

## 特徴

- **LLM非依存**: Claude, GPT, Gemini など任意のLLMエージェントを利用可能
- **階層構造**: 役割別に特化したエージェントが協調動作
- **tmux連携**: ターミナル分割で複数エージェントを同時起動・監視
- **人間の役割最小化**: 要件定義と最終レビューのみ

## AI進化の5段階（OpenAI提唱）

| Level | 名称 | 説明 |
|-------|------|------|
| L1 | Chatbot | 対話型AI |
| L2 | Reasoner | 推論可能なAI |
| L3 | Agent | 自律的に行動するAI |
| L4 | Innovator | 革新を生み出すAI |
| L5 | Organization | **← agent-corpはここを目指す** |

## 必要要件

- tmux 3.0以上
- Claude Code (`npm install -g @anthropic-ai/claude-code`)
- ANTHROPIC_API_KEY 環境変数の設定

## クイックスタート

```bash
# リポジトリをクローン
git clone https://github.com/kenimo49/agent-corp.git
cd agent-corp

# セッションを起動（自動監視モード）
./scripts/start.sh start

# セッションにアタッチ
./scripts/start.sh attach

# 4分割オーバービュー表示: Ctrl+b → 4

# 要件を送信（別ターミナルから）
./scripts/msg.sh send --from human --to ceo --type requirement \
    --title "機能追加" --body "ログイン機能を実装してください"

# セッション終了
./scripts/start.sh stop
```

## 処理フロー

```
human ──→ requirements/
              ↓
           CEO ←─────────────────┐
              ↓                  │
      instructions/pm        reports/pm
              ↓                  ↑
            PM ←─────────────────┤
              ↓                  │
         tasks/*          reports/engineers/*
              ↓                  ↑
        Engineers ───────────────┘
              ↓
        reports/human（最終報告）
```

## 起動モード

| モード | コマンド | 説明 |
|--------|----------|------|
| claude-loop（推奨） | `start.sh start` | 自動監視・自動処理 |
| claude | `start.sh start --llm claude` | 対話モード（手動） |
| aider | `start.sh start --llm aider` | Aider使用 |
| none | `start.sh start --llm none` | シェルのみ（デバッグ用） |

## ディレクトリ構成

```
agent-corp/
├── CLAUDE.md          # AIエージェント向けガイド
├── AGENTS.md          # CLAUDE.mdへの誘導
├── README.md
├── ROADMAP.md         # 開発ロードマップ
├── prompts/           # 役割別システムプロンプト
│   ├── ceo.md
│   ├── pm.md
│   └── engineers/
│       ├── frontend.md
│       ├── backend.md
│       └── security.md
├── scripts/           # 起動・管理スクリプト
│   ├── start.sh       # tmuxセッション起動
│   ├── msg.sh         # メッセージ送受信
│   └── agent-loop.sh  # エージェント監視ループ
├── shared/            # エージェント間共有ディレクトリ
└── docs/              # ドキュメント
    ├── _templates/    # テンプレート
    ├── flows/         # 処理フロー
    ├── knowledge/     # 実践的知識
    ├── design/        # 設計思想
    └── guide/         # ガイドライン
```

## 関連ドキュメント

| カテゴリ | ドキュメント | 説明 |
|---------|-------------|------|
| ガイド | [docs/guide/setup.md](./docs/guide/setup.md) | 環境構築・起動手順 |
| ガイド | [docs/guide/tutorial.md](./docs/guide/tutorial.md) | 5種類のチュートリアル |
| 設計 | [docs/design/org-hierarchy.md](./docs/design/org-hierarchy.md) | 組織階層設計 |
| 設計 | [docs/design/message-protocol.md](./docs/design/message-protocol.md) | 通信プロトコル |
| フロー | [docs/flows/README.md](./docs/flows/README.md) | 処理フロー一覧 |
| スクリプト | [scripts/README.md](./scripts/README.md) | スクリプトリファレンス |
| AI向け | [CLAUDE.md](./CLAUDE.md) | AIエージェント開発ガイド |

## ライセンス

MIT

## 参考

- [YouTube解説動画](https://youtube.com/shorts/vMhMWPYxLEs)
- [詳細解説動画](https://youtube.com/watch?v=Qxus36eijkM)
