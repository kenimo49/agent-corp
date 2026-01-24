# agent-corp

複数のAIエージェントを階層構造で連携させ、自律的に開発を行う「AI組織」を構築するためのフレームワーク。

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

- tmux
- 任意のLLMエージェント（Claude Code, Aider, GPT-CLI など）

## クイックスタート

```bash
# tmuxセッション作成
tmux new-session -s agent-corp

# ウィンドウ分割（例: 4分割）
# Ctrl+b % (縦分割)
# Ctrl+b " (横分割)

# 各ペインで役割別エージェントを起動
```

## ディレクトリ構成

```
agent-corp/
├── README.md
├── prompts/           # 役割別システムプロンプト
│   ├── ceo.md
│   ├── pm.md
│   └── engineers/
│       ├── frontend.md
│       ├── backend.md
│       └── security.md
├── scripts/           # 起動・管理スクリプト
└── docs/              # ドキュメント
```

## ライセンス

MIT

## 参考

- [YouTube解説動画](https://youtube.com/shorts/vMhMWPYxLEs)
- [詳細解説動画](https://youtube.com/watch?v=Qxus36eijkM)
