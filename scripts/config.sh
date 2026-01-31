#!/bin/bash

# config.sh - RAG設定読み込みスクリプト
# Usage: source ./scripts/config.sh

# =============================================================================
# .env ファイルの読み込み
# =============================================================================

_AGENT_CORP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -f "$_AGENT_CORP_DIR/.env" ]; then
    set -a
    # shellcheck source=/dev/null
    source "$_AGENT_CORP_DIR/.env"
    set +a
fi

# =============================================================================
# ターゲットプロジェクト設定
# =============================================================================

# エージェントが作業する対象プロジェクトのパス（未設定時はagent-corp自身）
export TARGET_PROJECT="${TARGET_PROJECT:-$_AGENT_CORP_DIR}"

# =============================================================================
# デフォルト設定
# =============================================================================

# RAG機能の有効/無効
export ENABLE_RAG="${ENABLE_RAG:-true}"

# ナレッジディレクトリのパス
export AGENT_KNOWLEDGE_DIR="${AGENT_KNOWLEDGE_DIR:-$HOME/.agent-corp/knowledge}"

# RAGコンテキストの最大行数
export RAG_CONTEXT_MAX_LINES="${RAG_CONTEXT_MAX_LINES:-200}"

# コンテキスト更新間隔（秒、0=毎回更新）
export RAG_CACHE_TTL="${RAG_CACHE_TTL:-0}"

# =============================================================================
# プロジェクト設定ファイルの読み込み
# =============================================================================

# プロジェクトルートの検出
detect_project_root() {
    local dir="${1:-.}"
    dir=$(cd "$dir" && pwd)

    while [ "$dir" != "/" ]; do
        if [ -f "$dir/.agent-config.yaml" ] || [ -f "$dir/.agent-config.yml" ]; then
            echo "$dir"
            return 0
        fi
        if [ -d "$dir/.git" ]; then
            echo "$dir"
            return 0
        fi
        dir=$(dirname "$dir")
    done

    echo "$(pwd)"
}

# YAML設定ファイルの読み込み
load_project_config() {
    local project_dir="${1:-$(detect_project_root)}"
    local config_file=""

    # 設定ファイルの検索
    for f in "$project_dir/.agent-config.yaml" "$project_dir/.agent-config.yml"; do
        if [ -f "$f" ]; then
            config_file="$f"
            break
        fi
    done

    if [ -z "$config_file" ]; then
        return 0
    fi

    # yqがある場合はYAML読み込み
    if command -v yq &>/dev/null; then
        local val

        # enable_rag
        val=$(yq -r '.rag.enabled // ""' "$config_file" 2>/dev/null)
        if [ -n "$val" ] && [ "$val" != "null" ]; then
            export ENABLE_RAG="$val"
        fi

        # knowledge_dir
        val=$(yq -r '.rag.knowledge_dir // ""' "$config_file" 2>/dev/null)
        if [ -n "$val" ] && [ "$val" != "null" ]; then
            export AGENT_KNOWLEDGE_DIR="$val"
        fi

        # max_lines
        val=$(yq -r '.rag.max_lines // ""' "$config_file" 2>/dev/null)
        if [ -n "$val" ] && [ "$val" != "null" ]; then
            export RAG_CONTEXT_MAX_LINES="$val"
        fi

        # cache_ttl
        val=$(yq -r '.rag.cache_ttl // ""' "$config_file" 2>/dev/null)
        if [ -n "$val" ] && [ "$val" != "null" ]; then
            export RAG_CACHE_TTL="$val"
        fi

        return 0
    fi

    # yqがない場合はgrepで簡易読み込み
    if grep -q "enabled:" "$config_file" 2>/dev/null; then
        local val=$(grep "enabled:" "$config_file" | head -1 | awk '{print $2}')
        if [ "$val" = "false" ]; then
            export ENABLE_RAG="false"
        fi
    fi
}

# =============================================================================
# ヘルパー関数
# =============================================================================

# RAGが有効かどうかを確認
is_rag_enabled() {
    [ "${ENABLE_RAG:-true}" = "true" ]
}

# ナレッジディレクトリを初期化
init_knowledge_dir() {
    mkdir -p "$AGENT_KNOWLEDGE_DIR/global"
    mkdir -p "$AGENT_KNOWLEDGE_DIR/projects"
}

# コンテキストキャッシュが有効かどうかを確認
is_cache_valid() {
    local cache_file="$1"
    local ttl="${RAG_CACHE_TTL:-0}"

    # TTLが0の場合は常に無効（毎回更新）
    if [ "$ttl" -eq 0 ]; then
        return 1
    fi

    # キャッシュファイルが存在しない場合は無効
    if [ ! -f "$cache_file" ]; then
        return 1
    fi

    # ファイルの更新時刻をチェック
    local now=$(date +%s)
    local mtime=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null)
    local age=$((now - mtime))

    [ "$age" -lt "$ttl" ]
}

# 設定を表示
show_config() {
    echo "=== RAG Configuration ==="
    echo "ENABLE_RAG:           $ENABLE_RAG"
    echo "AGENT_KNOWLEDGE_DIR:  $AGENT_KNOWLEDGE_DIR"
    echo "RAG_CONTEXT_MAX_LINES: $RAG_CONTEXT_MAX_LINES"
    echo "RAG_CACHE_TTL:        $RAG_CACHE_TTL"
    echo "========================="
}

# =============================================================================
# 初期化
# =============================================================================

# このスクリプトが直接実行された場合は設定を表示
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    load_project_config
    show_config
fi
