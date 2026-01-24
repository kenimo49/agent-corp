# 設定ガイド

agent-corpの各種設定方法を解説します。

---

## 目次

1. [環境変数](#環境変数)
2. [LLMエージェント設定](#llmエージェント設定)
3. [組織構成テンプレート](#組織構成テンプレート)
4. [プロンプトカスタマイズ](#プロンプトカスタマイズ)
5. [tmux設定](#tmux設定)

---

## 環境変数

### 必須設定

使用するLLMに応じてAPIキーを設定します。

```bash
# Claude Code (Anthropic)
export ANTHROPIC_API_KEY="sk-ant-xxxxx"

# OpenAI (GPT CLI, Aider)
export OPENAI_API_KEY="sk-xxxxx"
```

### オプション設定

```bash
# カスタムLLMコマンド
export CUSTOM_LLM_COMMAND="your-custom-llm"

# デバッグモード
export AGENT_CORP_DEBUG=1

# ログレベル
export AGENT_CORP_LOG_LEVEL="debug"  # debug, info, warn, error
```

### .envファイル

プロジェクトルートに`.env`ファイルを作成して環境変数を管理できます。

```bash
# .env
ANTHROPIC_API_KEY=sk-ant-xxxxx
OPENAI_API_KEY=sk-xxxxx
```

---

## LLMエージェント設定

### 設定ファイル

`config/agents.yaml`でLLMエージェントを設定します。

```yaml
# config/agents.yaml
version: "1.0"

defaults:
  llm: claude      # デフォルトLLM
  timeout: 300     # タイムアウト（秒）
  retry: 3         # リトライ回数
```

### 対応LLM一覧

| LLM | コマンド | 用途 |
|-----|---------|------|
| claude | `claude` | Claude Code (推奨) |
| aider | `aider` | Aider (マルチモデル対応) |
| gpt | `gpt` | GPT CLI |
| ollama | `ollama` | ローカルLLM |
| lmstudio | `lms` | LM Studio |
| cursor | `cursor` | Cursor IDE |
| custom | カスタム | ユーザー定義 |

### LLM選択方法

```bash
# 起動時に指定
./scripts/start.sh --llm claude
./scripts/start.sh --llm aider
./scripts/start.sh --llm ollama

# デフォルト変更（config/agents.yaml）
defaults:
  llm: aider
```

### カスタムLLM追加

```yaml
# config/agents.yaml に追加
llm_agents:
  my_custom_llm:
    name: "My Custom LLM"
    command: "my-llm-cli"
    args:
      - "--system"
      - "{prompt_file}"
    env:
      MY_API_KEY: "${MY_API_KEY}"
    install: "pip install my-llm-cli"
    docs: "https://example.com/docs"
```

---

## 組織構成テンプレート

### テンプレート一覧

`config/org-templates/`にテンプレートがあります。

#### default.yaml（標準構成）

```
human
  └── CEO
        └── PM
              ├── Frontend Engineer
              ├── Backend Engineer
              └── Security Engineer
```

#### minimal.yaml（最小構成）

```
human
  └── PM
        └── Engineer
```

#### large.yaml（大規模構成）

```
human
  └── CEO
        ├── CTO
        │     ├── PM Backend
        │     │     ├── Backend Senior
        │     │     ├── Backend Junior
        │     │     └── DBA
        │     └── PM Infra
        │           ├── DevOps
        │           ├── Security
        │           └── SRE
        └── CPO
              └── PM Frontend
                    ├── Frontend Senior
                    ├── Frontend Junior
                    └── UI Designer
```

### テンプレート選択

```bash
# 起動時に指定
./scripts/start.sh --template minimal
./scripts/start.sh --template large

# カスタムテンプレート
./scripts/start.sh --template ./my-org.yaml
```

### カスタムテンプレート作成

```yaml
# config/org-templates/custom.yaml
name: "Custom Organization"
description: "カスタム組織構成"

hierarchy:
  - role: lead
    reports_to: human
    subordinates:
      - dev1
      - dev2

  - role: dev1
    reports_to: lead
    subordinates: []

  - role: dev2
    reports_to: lead
    subordinates: []

custom_roles:
  lead:
    name: "Tech Lead AI"
    prompt: "prompts/custom/lead.md"
    description: "技術リード"

  dev1:
    name: "Developer 1 AI"
    prompt: "prompts/custom/dev.md"
    description: "開発者1"

  dev2:
    name: "Developer 2 AI"
    prompt: "prompts/custom/dev.md"
    description: "開発者2"

communication:
  flows:
    - from: human
      to: lead
      types: [requirement]
    - from: lead
      to: [dev1, dev2]
      types: [task]

tmux:
  windows:
    - name: lead
      roles: [lead]
    - name: devs
      layout: even-horizontal
      roles: [dev1, dev2]
```

---

## プロンプトカスタマイズ

### プロンプト構成

```
prompts/
├── ceo.md              # CEO用プロンプト
├── pm.md               # PM用プロンプト
└── engineers/
    ├── frontend.md     # フロントエンド
    ├── backend.md      # バックエンド
    └── security.md     # セキュリティ
```

### プロンプト構造

各プロンプトは以下のセクションで構成されます。

```markdown
# [ロール名]

## 役割と責任
[このエージェントの責任範囲]

## 上位者
[報告先の情報]

## 下位者
[管理対象の情報]

## コミュニケーション
[通信プロトコルの詳細]

## 行動指針
[判断基準と優先事項]
```

### カスタマイズ例

```markdown
# カスタムPM

## 役割と責任
- アジャイル開発のスクラムマスター
- 2週間スプリントの管理
- デイリースタンドアップの進行

## 追加ルール
- 見積もりはストーリーポイントで行う
- 技術的負債は20%以内に抑える
- コードレビューは必須
```

### プロンプト変数

プロンプト内で使用可能な変数：

| 変数 | 説明 |
|------|------|
| `{role}` | 現在のロール名 |
| `{superior}` | 上位者のロール |
| `{subordinates}` | 下位者リスト |
| `{project_root}` | プロジェクトルート |

---

## tmux設定

### レイアウトオプション

```yaml
# config/org-templates/*.yaml
tmux:
  windows:
    - name: engineers
      layout: main-vertical    # レイアウト
      roles: [frontend, backend, security]
```

| レイアウト | 説明 |
|-----------|------|
| `even-horizontal` | 水平均等分割 |
| `even-vertical` | 垂直均等分割 |
| `main-horizontal` | メイン + 水平サブ |
| `main-vertical` | メイン + 垂直サブ |
| `tiled` | タイル状配置 |

### モニターウィンドウ

```yaml
tmux:
  windows:
    # エージェントウィンドウ
    - name: pm
      roles: [pm]

    # カスタムコマンドウィンドウ
    - name: monitor
      command: "watch -n 2 'ls -la shared/'"

    - name: logs
      command: "./scripts/monitor.sh log"
```

### キーバインド

tmuxセッション内での操作：

| キー | 動作 |
|------|------|
| `Ctrl+b w` | ウィンドウ一覧 |
| `Ctrl+b n` | 次のウィンドウ |
| `Ctrl+b p` | 前のウィンドウ |
| `Ctrl+b d` | セッションをデタッチ |
| `Ctrl+b [` | スクロールモード |

---

## 設定の優先順位

設定は以下の順序で適用されます（後の設定が優先）：

1. `config/agents.yaml` のデフォルト値
2. 組織テンプレートの設定
3. 環境変数
4. コマンドライン引数

```bash
# 例: デフォルトはclaudeだが、aiderで起動
./scripts/start.sh --llm aider
```

---

## 関連ドキュメント

- [セットアップガイド](./setup.md) - 初期設定
- [チュートリアル](./tutorial.md) - 実践的な使い方
- [トラブルシューティング](./troubleshooting.md) - 問題解決
