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

## Claude Code の主要オプション

`claude -p` で利用可能な主要オプション:

| オプション | 説明 | 用途 |
|-----------|------|------|
| `--system-prompt` | システムプロンプトを分離して指定 | ロール定義 |
| `--allowedTools` | 使用可能なツールを指定 | `"Bash,Edit,Read,Write"` |
| `--add-dir` | 追加のディレクトリアクセスを許可 | TARGET_PROJECT指定 |
| `--dangerously-skip-permissions` | 権限確認をスキップ | 自動実行 |
| `--chrome` | Claude in Chrome連携を有効化 | ブラウザ操作 |
| `--no-chrome` | Claude in Chrome連携を無効化 | ブラウザ不要時 |

### --chrome オプション

`--chrome` を付けると、Chrome拡張「Claude in Chrome」のMCPツールが `claude -p` でも利用可能になる。

```bash
# ブラウザでページを開いて確認
claude -p "http://localhost:3000 を開いてUIを確認してください" \
    --chrome \
    --dangerously-skip-permissions
```

**利用可能になるツール例**:
- `mcp__claude-in-chrome__navigate`: URL遷移
- `mcp__claude-in-chrome__read_page`: ページ内容の読み取り
- `mcp__claude-in-chrome__computer`: マウス/キーボード操作、スクリーンショット
- `mcp__claude-in-chrome__find`: 要素の検索
- `mcp__claude-in-chrome__javascript_tool`: JavaScript実行

**前提条件**:
- Google Chrome がインストールされていること
- Claude in Chrome 拡張がインストール・有効化されていること
- Chrome が起動していること（WSLg経由でも可）

**agent-corpでの活用**:
- Frontend Engineer: UIの挙動チェック、レスポンシブ確認
- QA（将来）: E2Eブラウザテスト、スクリーンショットによる視覚的確認

## agent-loop.sh での実装

`scripts/agent-loop.sh` の `execute_llm()` 関数で差異を吸収しています。
`--chrome` はオプションで、ロールに応じて有効/無効を切り替えます。

```bash
execute_llm() {
    local system_prompt="$1"
    local task_prompt="$2"

    case $LLM_TYPE in
        claude)
            claude -p "$task_prompt" \
                --system-prompt "$system_prompt" \
                --allowedTools "Bash,Edit,Read,Write" \
                --add-dir "$TARGET_PROJECT" \
                ${ENABLE_CHROME:+--chrome} \
                --dangerously-skip-permissions 2>&1
            ;;
        codex)
            codex exec "$system_prompt

$task_prompt" 2>&1
            ;;
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
