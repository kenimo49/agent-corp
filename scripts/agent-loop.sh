#!/bin/bash

# agent-loop.sh - エージェント監視ループスクリプト
# 指定されたディレクトリを監視し、新しいファイルがあれば claude -p で処理する

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
POLL_INTERVAL=${POLL_INTERVAL:-5}
LLM_TYPE=${LLM_TYPE:-claude}

# RAG設定読み込み
source "$PROJECT_DIR/scripts/config.sh"
load_project_config "$PROJECT_DIR"

# 色付きログ
log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[OK]\033[0m $1"; }
log_warn() { echo -e "\033[0;33m[WARN]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; }

# 起動時バリデーション
validate_environment() {
    local role=$1
    local prompt_file=$2

    # TARGET_PROJECTの存在チェック
    if [ ! -d "$TARGET_PROJECT" ]; then
        log_error "TARGET_PROJECT が存在しません: $TARGET_PROJECT"
        log_error ".env を確認してください"
        exit 1
    fi

    # プロンプトファイルの存在チェック
    if [ ! -f "$prompt_file" ]; then
        log_warn "プロンプトファイルが見つかりません: $prompt_file"
        log_warn "フォールバックプロンプトを使用します（品質が低下する可能性があります）"
    fi

    log_info "環境チェック完了 - ロール: $role, TARGET_PROJECT: $TARGET_PROJECT"
}

# LLMコマンド実行（LLM非依存）
# 引数: $1=システムプロンプト, $2=タスクプロンプト
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
        *)
            log_error "未対応のLLMタイプ: $LLM_TYPE"
            return 1
            ;;
    esac
}

# RAGコンテキスト取得
get_project_context() {
    local task_content="${1:-}"

    if ! is_rag_enabled; then
        return 0
    fi

    # コンテキスト解析スクリプトを実行
    local context
    context=$("$PROJECT_DIR/scripts/analyze-context.sh" "$TARGET_PROJECT" "$task_content" 2>/dev/null) || {
        log_error "RAGコンテキスト生成に失敗"
        return 0
    }

    echo "$context"
}

# RAGコンテキストをタスクプロンプトに注入（システムプロンプトは分離）
build_task_prompt() {
    local task_content="$1"
    local task_prompt="$2"

    local rag_context=""
    if is_rag_enabled; then
        rag_context=$(get_project_context "$task_content")
    fi

    if [ -n "$rag_context" ]; then
        echo "[プロジェクトコンテキスト]
$rag_context

---
$task_prompt"
    else
        echo "$task_prompt"
    fi
}

usage() {
    cat << EOF
Usage: $0 <role> [llm_type]

Roles:
    ceo         CEOエージェント（requirements → instructions/pm）
    pm          PMエージェント（instructions/pm → tasks/*）
    intern      インターン（tasks/intern → reports, Gemini使用）
    frontend    Frontendエンジニア（tasks/frontend → reports）
    backend     Backendエンジニア（tasks/backend → reports）
    security    Securityエンジニア（tasks/security → reports）

LLM Types:
    claude      Claude Code（デフォルト）
    codex       OpenAI Codex CLI
    # gemini      Google Gemini CLI（現在無効）

Environment:
    POLL_INTERVAL           監視間隔（秒）[default: 5]
    LLM_TYPE                使用するLLM [default: claude]
    ENABLE_RAG              RAGコンテキスト有効化 [default: true]
    AGENT_KNOWLEDGE_DIR     ナレッジディレクトリ [default: ~/.agent-corp/knowledge]
    RAG_CONTEXT_MAX_LINES   コンテキスト最大行数 [default: 200]

Examples:
    $0 ceo
    $0 pm codex
    POLL_INTERVAL=10 $0 frontend gemini
EOF
}

# 処理済みファイルを記録
PROCESSED_DIR="$PROJECT_DIR/shared/.processed"
mkdir -p "$PROCESSED_DIR"

is_processed() {
    local file=$1
    local hash=$(echo "$file" | md5sum | cut -d' ' -f1)
    [ -f "$PROCESSED_DIR/$hash" ]
}

mark_processed() {
    local file=$1
    local hash=$(echo "$file" | md5sum | cut -d' ' -f1)
    touch "$PROCESSED_DIR/$hash"
}

# CEOエージェント
run_ceo() {
    local watch_dir="$PROJECT_DIR/shared/requirements"
    local report_dir="$PROJECT_DIR/shared/reports/pm"
    local intern_report_dir="$PROJECT_DIR/shared/reports/intern"
    local output_dir="$PROJECT_DIR/shared/instructions/pm"
    local final_report_dir="$PROJECT_DIR/shared/reports/human"
    local prompt_file="$PROJECT_DIR/prompts/ceo.md"

    validate_environment "ceo" "$prompt_file"
    mkdir -p "$watch_dir" "$report_dir" "$intern_report_dir" "$output_dir" "$final_report_dir"

    log_info "CEO Agent 起動 - 監視: $watch_dir, $report_dir, $intern_report_dir"
    is_rag_enabled && log_info "RAG有効 - ナレッジディレクトリ: $AGENT_KNOWLEDGE_DIR"

    while true; do
        # 1. 新しい要件を処理
        for file in "$watch_dir"/*.md; do
            [ -f "$file" ] || continue
            is_processed "$file" && continue

            log_info "新しい要件を検出: $(basename "$file")"

            local content=$(cat "$file")
            local basename=$(basename "$file" .md)
            local output_file="$output_dir/${basename}-instruction.md"

            local system_prompt=$(cat "$prompt_file" 2>/dev/null || echo "You are a CEO.")
            local task_prompt="以下の要件を分析し、PMへの指示を作成してください。
出力はMarkdown形式で、[INSTRUCTION TO: PM]フォーマットに従ってください。

要件ファイル: $file
---
$content"

            local final_task_prompt
            final_task_prompt=$(build_task_prompt "$content" "$task_prompt")

            log_info "$LLM_TYPE APIで処理中..."
            response=$(execute_llm "$system_prompt" "$final_task_prompt") || {
                log_error "$LLM_TYPE API エラー"
                continue
            }

            echo "$response" > "$output_file"
            mark_processed "$file"
            log_success "指示を作成: $output_file"
        done

        # 2. PMからの報告を処理
        for file in "$report_dir"/*.md; do
            [ -f "$file" ] || continue
            is_processed "$file" && continue

            log_info "PMから報告を受信: $(basename "$file")"

            local content=$(cat "$file")
            local basename=$(basename "$file" .md)
            local output_file="$final_report_dir/${basename}-final.md"

            local system_prompt=$(cat "$prompt_file" 2>/dev/null || echo "You are a CEO.")
            local task_prompt="PMからの報告を確認し、人間への最終報告を作成してください。

報告ファイル: $file
---
$content"

            local final_task_prompt
            final_task_prompt=$(build_task_prompt "$content" "$task_prompt")

            log_info "最終報告を作成中..."
            response=$(execute_llm "$system_prompt" "$final_task_prompt") || {
                log_error "$LLM_TYPE API エラー"
                continue
            }

            echo "$response" > "$output_file"
            mark_processed "$file"
            log_success "最終報告を作成: $output_file"
        done

        # 3. インターンからの報告を処理
        for file in "$intern_report_dir"/*.md; do
            [ -f "$file" ] || continue
            is_processed "$file" && continue

            log_info "インターンから報告を受信: $(basename "$file")"

            local content=$(cat "$file")
            local basename=$(basename "$file" .md)
            local output_file="$final_report_dir/${basename}-final.md"

            local system_prompt=$(cat "$prompt_file" 2>/dev/null || echo "You are a CEO.")
            local task_prompt="インターンからの調査報告を確認し、人間への最終報告を作成してください。
内容を要約し、重要なポイントと推奨事項を明確にしてください。

報告ファイル: $file
---
$content"

            local final_task_prompt
            final_task_prompt=$(build_task_prompt "$content" "$task_prompt")

            log_info "最終報告を作成中..."
            response=$(execute_llm "$system_prompt" "$final_task_prompt") || {
                log_error "$LLM_TYPE API エラー"
                continue
            }

            echo "$response" > "$output_file"
            mark_processed "$file"
            log_success "最終報告を作成: $output_file"
        done

        sleep "$POLL_INTERVAL"
    done
}

# PMエージェント
run_pm() {
    local watch_dir="$PROJECT_DIR/shared/instructions/pm"
    local output_dir="$PROJECT_DIR/shared/tasks"
    local report_watch_dir="$PROJECT_DIR/shared/reports/engineers"
    local report_output_dir="$PROJECT_DIR/shared/reports/pm"
    local prompt_file="$PROJECT_DIR/prompts/pm.md"

    validate_environment "pm" "$prompt_file"
    mkdir -p "$watch_dir" "$output_dir"/{frontend,backend,security} "$report_watch_dir"/{frontend,backend,security} "$report_output_dir"

    log_info "PM Agent 起動 - 監視: $watch_dir, $report_watch_dir"

    while true; do
        # 1. CEOからの指示を処理
        for file in "$watch_dir"/*.md; do
            [ -f "$file" ] || continue
            is_processed "$file" && continue

            log_info "新しい指示を検出: $(basename "$file")"

            local content=$(cat "$file")
            local basename=$(basename "$file" .md)

            local system_prompt=$(cat "$prompt_file" 2>/dev/null || echo "You are a PM.")
            local task_prompt="以下のCEOからの指示を分析し、エンジニアへのタスクに分解してください。

## 出力形式
以下の3セクションに分けて出力してください。該当タスクがない場合は「該当なし」と記載。

### FRONTEND_TASK
（フロントエンドエンジニアへのタスク内容）

### BACKEND_TASK
（バックエンドエンジニアへのタスク内容）

### SECURITY_TASK
（セキュリティエンジニアへのタスク内容）

---
指示ファイル: $file
---
$content"

            local final_task_prompt
            final_task_prompt=$(build_task_prompt "$content" "$task_prompt")

            log_info "$LLM_TYPE APIで処理中..."
            response=$(execute_llm "$system_prompt" "$final_task_prompt") || {
                log_error "$LLM_TYPE API エラー"
                continue
            }

            # セクションごとにタスクを抽出して保存
            # ヘッダーの大文字小文字・空白揺れに対応し、TAB区切りでコロン衝突を回避
            echo "$response" | awk '
                BEGIN { IGNORECASE=1 }
                /^#{2,3}\s*FRONTEND[_\s-]*TASK/ { section="frontend"; next }
                /^#{2,3}\s*BACKEND[_\s-]*TASK/ { section="backend"; next }
                /^#{2,3}\s*SECURITY[_\s-]*TASK/ { section="security"; next }
                /^#{2,3}\s/ { section="" }
                section != "" && !/^該当なし/ && !/^[Nn]\/?[Aa]/ && !/^なし/ && !/^\s*$/ {
                    print section "\t" $0
                }
            ' | while IFS=$'\t' read -r role line; do
                if [ -n "$role" ] && [ -n "$line" ]; then
                    echo "$line" >> "$output_dir/${role}/${basename}-task.md"
                fi
            done

            # タスクファイルが作成されたか確認
            local tasks_created=false
            for role in frontend backend security; do
                if [ -f "$output_dir/${role}/${basename}-task.md" ]; then
                    log_success "タスク作成: tasks/${role}/${basename}-task.md"
                    tasks_created=true
                fi
            done

            if [ "$tasks_created" = false ]; then
                log_error "タスクファイルが作成されませんでした。LLMの出力形式を確認してください。"
                log_info "期待形式: ### FRONTEND_TASK / ### BACKEND_TASK / ### SECURITY_TASK"
            fi

            mark_processed "$file"
        done

        # 2. エンジニアからの報告を集約してCEOに報告
        for role in frontend backend security; do
            for file in "$report_watch_dir/$role"/*.md; do
                [ -f "$file" ] || continue
                is_processed "$file" && continue

                log_info "エンジニア($role)から報告: $(basename "$file")"

                local content=$(cat "$file")
                local basename=$(basename "$file" .md)
                local output_file="$report_output_dir/${basename}-pm-report.md"

                local system_prompt=$(cat "$prompt_file" 2>/dev/null || echo "You are a PM.")
                local task_prompt="エンジニア($role)からの報告を確認し、CEOへの進捗報告を作成してください。

報告ファイル: $file
---
$content"

                local final_task_prompt
                final_task_prompt=$(build_task_prompt "$content" "$task_prompt")

                log_info "CEOへの報告を作成中..."
                response=$(execute_llm "$system_prompt" "$final_task_prompt") || {
                    log_error "$LLM_TYPE API エラー"
                    continue
                }

                echo "$response" > "$output_file"
                mark_processed "$file"
                log_success "CEOへ報告: $output_file"
            done
        done

        sleep "$POLL_INTERVAL"
    done
}

# Internエージェント
run_intern() {
    local watch_dir="$PROJECT_DIR/shared/tasks/intern"
    local output_dir="$PROJECT_DIR/shared/reports/intern"
    local prompt_file="$PROJECT_DIR/prompts/intern.md"

    validate_environment "intern" "$prompt_file"
    mkdir -p "$watch_dir" "$output_dir"

    log_info "Intern Agent 起動 - 監視: $watch_dir (LLM: $LLM_TYPE)"

    while true; do
        for file in "$watch_dir"/*.md; do
            [ -f "$file" ] || continue
            is_processed "$file" && continue

            log_info "新しいタスクを検出: $(basename "$file")"

            local content=$(cat "$file")
            local basename=$(basename "$file" .md)
            local output_file="$output_dir/${basename}-report.md"

            local system_prompt=$(cat "$prompt_file" 2>/dev/null || echo "You are an intern.")
            local task_prompt="以下のタスクを実行し、CEOへの報告を作成してください。

タスクファイル: $file
---
$content"

            local final_task_prompt
            final_task_prompt=$(build_task_prompt "$content" "$task_prompt")

            log_info "$LLM_TYPE APIで処理中..."
            response=$(execute_llm "$system_prompt" "$final_task_prompt") || {
                log_error "$LLM_TYPE API エラー"
                continue
            }

            echo "$response" > "$output_file"
            mark_processed "$file"
            log_success "レポート作成: $output_file"
        done

        sleep "$POLL_INTERVAL"
    done
}

# Engineerエージェント
run_engineer() {
    local role=$1
    local watch_dir="$PROJECT_DIR/shared/tasks/$role"
    local output_dir="$PROJECT_DIR/shared/reports/engineers/$role"
    local prompt_file="$PROJECT_DIR/prompts/engineers/${role}.md"

    validate_environment "$role" "$prompt_file"
    mkdir -p "$watch_dir" "$output_dir"

    # frontendロールはClaude in Chrome連携を有効化（UI挙動チェック用）
    if [ "$role" = "frontend" ]; then
        export ENABLE_CHROME=1
        log_info "$role Engineer Agent 起動 - 監視: $watch_dir (Chrome連携: 有効)"
    else
        unset ENABLE_CHROME
        log_info "$role Engineer Agent 起動 - 監視: $watch_dir"
    fi

    while true; do
        for file in "$watch_dir"/*.md; do
            [ -f "$file" ] || continue
            is_processed "$file" && continue

            log_info "新しいタスクを検出: $(basename "$file")"

            local content=$(cat "$file")
            local basename=$(basename "$file" .md)
            local output_file="$output_dir/${basename}-report.md"

            local system_prompt=$(cat "$prompt_file" 2>/dev/null || echo "You are a $role engineer.")
            local task_prompt="以下のタスクを実行し、結果を報告してください。

タスクファイル: $file
---
$content"

            local final_task_prompt
            final_task_prompt=$(build_task_prompt "$content" "$task_prompt")

            log_info "$LLM_TYPE APIで処理中..."
            response=$(execute_llm "$system_prompt" "$final_task_prompt") || {
                log_error "$LLM_TYPE API エラー"
                continue
            }

            echo "$response" > "$output_file"
            mark_processed "$file"
            log_success "レポート作成: $output_file"
        done

        sleep "$POLL_INTERVAL"
    done
}

# メイン
main() {
    local role=${1:-}
    local llm_type=${2:-claude}

    # LLMタイプを環境変数に設定
    export LLM_TYPE="$llm_type"

    if [ -z "$role" ]; then
        usage
        exit 1
    fi

    case $role in
        ceo)
            run_ceo
            ;;
        pm)
            run_pm
            ;;
        intern)
            run_intern
            ;;
        frontend|backend|security)
            run_engineer "$role"
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            log_error "不明なロール: $role"
            usage
            exit 1
            ;;
    esac
}

main "$@"
