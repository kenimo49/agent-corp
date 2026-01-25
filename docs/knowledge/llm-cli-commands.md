# LLM CLI コマンド差異

各LLM CLIツールでプロンプトを渡す方法の違いをまとめます。

## コマンド比較表

| LLM | プロンプト実行コマンド | 対話モード起動 |
|-----|----------------------|---------------|
| **Claude Code** | `claude -p "prompt"` | `claude` |
| **OpenAI Codex** | `codex exec "prompt"` | `codex` |
<!-- | **Gemini CLI** | `gemini -p "prompt"` ※要 `< /dev/null` | `gemini` | -->

## 詳細

### Claude Code

```bash
# プロンプト実行（非対話）
claude -p "Hello, world"

# 対話モード
claude

# システムプロンプト付き対話モード
claude --system-prompt "You are a helpful assistant."
```

**特徴**:
- `-p` オプションでプロンプトを渡す
- 標準入力の追加入力なしで動作

### OpenAI Codex

```bash
# プロンプト実行（非対話）
codex exec "Hello, world"

# 対話モード
codex
```

**特徴**:
- `exec` サブコマンドでプロンプトを渡す（`-p` ではない）
- `-p` オプションは存在しない

**認証**:
```bash
# サブスクリプション認証（推奨）
codex login
# ブラウザでOpenAIアカウントにログイン
# ChatGPT Plus/Pro/Teamが必要

# または APIキー
export OPENAI_API_KEY="your-api-key"
```

<!--
### Google Gemini CLI（現在無効）

```bash
# プロンプト実行（非対話）
gemini -p "Hello, world" < /dev/null

# 対話モード
gemini
```

**特徴**:
- `-p` オプションでプロンプトを渡す
- 標準入力を待つため、`< /dev/null` が必要
- 現在、スクリプトからの呼び出しに問題があり無効化中
-->

## agent-loop.sh での実装

`scripts/agent-loop.sh` の `execute_llm()` 関数で差異を吸収しています：

```bash
execute_llm() {
    local full_prompt=$1

    case $LLM_TYPE in
        claude)
            claude -p "$full_prompt" 2>&1
            ;;
        codex)
            codex exec "$full_prompt" 2>&1
            ;;
        # gemini)
        #     gemini -p "$full_prompt" < /dev/null 2>&1
        #     ;;
    esac
}
```

## 新しいLLM CLIを追加する場合

1. `scripts/agent-loop.sh` の `execute_llm()` に case を追加
2. `scripts/start.sh` の `get_agent_command()` に case を追加
3. このドキュメントに情報を追記

## 関連ファイル

- `scripts/agent-loop.sh` - LLM実行関数
- `scripts/start.sh` - セッション起動スクリプト
- `docs/guide/setup.md` - セットアップガイド

## 更新履歴

- 2026-01-25: 初版作成（Claude, Codex対応、Gemini無効化）
