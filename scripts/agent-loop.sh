#!/bin/bash

# agent-loop.sh - エージェント監視ループスクリプト
# 指定されたディレクトリを監視し、新しいファイルがあれば claude -p で処理する

# set -e を使わない: 長期実行ループでは個別エラーハンドリング（|| { ... }）で対応
# claude CLIがnon-zeroを返した際にスクリプト全体が死ぬのを防ぐ

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
POLL_INTERVAL=${POLL_INTERVAL:-5}
LLM_TYPE=${LLM_TYPE:-claude}
SESSION_COST_LIMIT=${SESSION_COST_LIMIT:-0}  # 5時間セッションのコスト上限（USD）。0=無制限
SESSION_COST_WARN_PCT=${SESSION_COST_WARN_PCT:-80}  # 警告閾値（%）

# ロール別モデル設定（claude使用時のみ有効）
# 個別指定が未設定の場合は CLAUDE_MODEL のデフォルトを使用
CLAUDE_MODEL=${CLAUDE_MODEL:-}              # 全ロール共通デフォルト（空=CLIデフォルト）
CEO_MODEL=${CEO_MODEL:-$CLAUDE_MODEL}
PM_MODEL=${PM_MODEL:-$CLAUDE_MODEL}
INTERN_MODEL=${INTERN_MODEL:-$CLAUDE_MODEL}  # codex使用時は無関係。claude切替時に有効
FRONTEND_MODEL=${FRONTEND_MODEL:-$CLAUDE_MODEL}
BACKEND_MODEL=${BACKEND_MODEL:-$CLAUDE_MODEL}
SECURITY_MODEL=${SECURITY_MODEL:-$CLAUDE_MODEL}
QA_MODEL=${QA_MODEL:-$CLAUDE_MODEL}
PO_MODEL=${PO_MODEL:-$CLAUDE_MODEL}
PERFORMANCE_ANALYST_MODEL=${PERFORMANCE_ANALYST_MODEL:-$CLAUDE_MODEL}
PERF_ANALYST_INTERVAL=${PERF_ANALYST_INTERVAL:-300}  # Performance Analyst チェック間隔（秒）

# RAG設定読み込み
source "$PROJECT_DIR/scripts/config.sh"
load_project_config "$PROJECT_DIR"

# 色付きログ（タイムスタンプ付き）
_ts() { date '+%H:%M:%S'; }
log_info() { echo -e "\033[2m$(_ts)\033[0m \033[0;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[2m$(_ts)\033[0m \033[0;32m[OK]\033[0m $1"; }
log_warn() { echo -e "\033[2m$(_ts)\033[0m \033[0;33m[WARN]\033[0m $1"; }
log_error() { echo -e "\033[2m$(_ts)\033[0m \033[0;31m[ERROR]\033[0m $1"; }

# 5時間ローリングウィンドウのコストチェック
# 戻り値: 0=OK, 1=閾値超過（一時停止すべき）
check_session_cost() {
    # SESSION_COST_LIMIT が 0 または未設定なら常にOK
    if [ "$SESSION_COST_LIMIT" = "0" ] || [ -z "$SESSION_COST_LIMIT" ]; then
        return 0
    fi

    local usage_log="$PROJECT_DIR/shared/.usage-log.jsonl"
    if [ ! -f "$usage_log" ]; then
        return 0
    fi

    # 5時間前のタイムスタンプ（UTC）
    local five_hours_ago
    five_hours_ago=$(date -u -d '5 hours ago' '+%Y-%m-%dT%H:%M:%SZ')

    # 直近5時間の累計コストを算出
    local total_cost
    total_cost=$(jq -s --arg since "$five_hours_ago" \
        '[.[] | select(.timestamp >= $since) | .cost_usd // 0] | add // 0' \
        "$usage_log" 2>/dev/null)

    # 閾値計算（SESSION_COST_LIMIT の SESSION_COST_WARN_PCT%）
    local threshold
    threshold=$(echo "$SESSION_COST_LIMIT $SESSION_COST_WARN_PCT" | awk '{printf "%.4f", $1 * $2 / 100}')

    local pct
    pct=$(echo "$total_cost $SESSION_COST_LIMIT" | awk '{if ($2 > 0) printf "%.1f", $1 / $2 * 100; else print "0"}')

    if [ "$(echo "$total_cost $threshold" | awk '{print ($1 >= $2) ? 1 : 0}')" = "1" ]; then
        log_warn "セッションコスト閾値超過: \$${total_cost} / \$${SESSION_COST_LIMIT} (${pct}%) - 上限の${SESSION_COST_WARN_PCT}%に到達"
        return 1
    fi

    return 0
}

# セッションコスト超過時の一時停止処理
# リセットまで待機し、usageログの5時間枠が回復したら再開する
wait_for_session_reset() {
    log_warn "=== セッションコスト制限により一時停止 ==="
    log_warn "SESSION_COST_LIMIT=\$${SESSION_COST_LIMIT} の ${SESSION_COST_WARN_PCT}% に到達しました"
    log_warn "5時間ローリングウィンドウのコストが下がるまで待機します..."

    while true; do
        sleep 300  # 5分ごとにチェック
        if check_session_cost; then
            log_success "セッションコストが閾値以下に回復しました。処理を再開します。"
            return 0
        fi
        log_info "まだ閾値超過中... 5分後に再チェックします"
    done
}

# 起動時バリデーション
validate_environment() {
    local role=$1
    local prompt_file=$2

    # jqの存在チェック（claude --output-format json の解析に必要）
    if ! command -v jq >/dev/null 2>&1; then
        log_error "jq がインストールされていません。sudo apt install jq でインストールしてください"
        exit 1
    fi

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

    # モデル設定の表示
    local model
    model=$(resolve_model "$role")
    log_info "環境チェック完了 - ロール: $role, TARGET_PROJECT: $TARGET_PROJECT, モデル: ${model:-CLIデフォルト}"
}

# ロール名からモデル設定を解決
# 引数: $1=ロール名
resolve_model() {
    local role="$1"
    case "$role" in
        ceo)      echo "$CEO_MODEL" ;;
        pm)       echo "$PM_MODEL" ;;
        intern)   echo "$INTERN_MODEL" ;;
        frontend) echo "$FRONTEND_MODEL" ;;
        backend)  echo "$BACKEND_MODEL" ;;
        security) echo "$SECURITY_MODEL" ;;
        qa)       echo "$QA_MODEL" ;;
        po)       echo "$PO_MODEL" ;;
        performance_analyst) echo "$PERFORMANCE_ANALYST_MODEL" ;;
        *)        echo "$CLAUDE_MODEL" ;;
    esac
}

# LLMコマンド実行（LLM非依存）
# 引数: $1=システムプロンプト, $2=タスクプロンプト, $3=タスクファイル名（オプション）
execute_llm() {
    local system_prompt="$1"
    local task_prompt="$2"
    local task_file="${3:-}"
    local work_dir="${4:-$TARGET_PROJECT}"

    case $LLM_TYPE in
        claude)
            # ロール別モデルを解決
            local model
            model=$(resolve_model "${CURRENT_ROLE:-}")

            local raw_output
            local claude_exit=0
            raw_output=$(claude -p "$task_prompt" \
                --system-prompt "$system_prompt" \
                --allowedTools "Bash,Edit,Read,Write" \
                --add-dir "$work_dir" \
                ${ENABLE_CHROME:+--chrome} \
                ${model:+--model "$model"} \
                --output-format json \
                --dangerously-skip-permissions) || claude_exit=$?

            if [ "$claude_exit" -ne 0 ] || ! echo "$raw_output" | jq -e '.result' >/dev/null 2>&1; then
                log_error "claude API レスポンスの解析に失敗（フォールバック: 生テキスト出力）"
                echo "$raw_output"
                return 1
            fi

            # Usage情報をJSONLログに記録
            local usage_log="$PROJECT_DIR/shared/.usage-log.jsonl"
            echo "$raw_output" | jq -c \
                --arg ts "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
                --arg role "${CURRENT_ROLE:-unknown}" \
                --arg task "$task_file" \
                '{timestamp: $ts, role: $role, task: $task, model: ([.modelUsage | keys[]] | join(",")), models: [.modelUsage | keys[]], model_usage: .modelUsage, input_tokens: .usage.input_tokens, output_tokens: .usage.output_tokens, cache_creation_input_tokens: .usage.cache_creation_input_tokens, cache_read_input_tokens: .usage.cache_read_input_tokens, cost_usd: .total_cost_usd, duration_ms: .duration_ms, session_id: .session_id}' \
                >> "$usage_log" 2>/dev/null

            # トークン使用量をログ表示
            local in_tok out_tok cost models
            in_tok=$(echo "$raw_output" | jq '.usage.input_tokens // 0')
            out_tok=$(echo "$raw_output" | jq '.usage.output_tokens // 0')
            cost=$(echo "$raw_output" | jq -r '.total_cost_usd // 0')
            models=$(echo "$raw_output" | jq -r '[.modelUsage | keys[]] | join(", ")')
            log_info "Token使用量: input=$in_tok output=$out_tok cost=\$${cost} models=[$models]"

            # レスポンス本文のみ出力
            echo "$raw_output" | jq -r '.result'
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
    qa          QA（tasks/qa → reports/qa）
    po          Product Owner（tasks/po → reports/po）
    performance_analyst  Performance Analyst（usage-log分析・最適化提案）

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
    SESSION_COST_LIMIT      5時間セッションのコスト上限USD [default: 0（無制限）]
    SESSION_COST_WARN_PCT   コスト警告閾値% [default: 80]
    CLAUDE_MODEL            全ロール共通のモデル [default: CLIデフォルト]
    CEO_MODEL               CEOのモデル [default: CLAUDE_MODEL]
    PM_MODEL                PMのモデル [default: CLAUDE_MODEL]
    FRONTEND_MODEL          Frontendのモデル [default: CLAUDE_MODEL]
    BACKEND_MODEL           Backendのモデル [default: CLAUDE_MODEL]
    SECURITY_MODEL          Securityのモデル [default: CLAUDE_MODEL]
    QA_MODEL                QAのモデル [default: CLAUDE_MODEL]
    PO_MODEL                POのモデル [default: CLAUDE_MODEL]
    INTERN_MODEL            Internのモデル [default: CLAUDE_MODEL]
    PERFORMANCE_ANALYST_MODEL Performance Analystのモデル [default: CLAUDE_MODEL]
    PERF_ANALYST_INTERVAL   Performance Analyst チェック間隔（秒）[default: 300]

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

# タスクファイル存在確認（共通関数）
# 戻り値: 0=存在する, 1=存在しない（LLM呼び出しスキップ）
check_task_file_exists() {
    local file="$1"
    if [ ! -f "$file" ]; then
        log_info "タスクファイル不在: $(basename "$file")"
        return 1
    fi
    return 0
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
            check_task_file_exists "$file" || continue

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
            response=$(execute_llm "$system_prompt" "$final_task_prompt" "$(basename "$file")") || {
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
            check_task_file_exists "$file" || continue

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

            log_info "最終報告を作成中... ($LLM_TYPE APIで処理中)"
            response=$(execute_llm "$system_prompt" "$final_task_prompt" "$(basename "$file")") || {
                log_error "$LLM_TYPE API エラー - 最終報告の作成に失敗"
                continue
            }

            echo "$response" > "$output_file"
            mark_processed "$file"
            log_success "最終報告を作成: $output_file"
            log_info "人間への報告完了 - $(basename "$output_file")"
        done

        # 3. インターンからの報告を処理
        for file in "$intern_report_dir"/*.md; do
            [ -f "$file" ] || continue
            is_processed "$file" && continue
            check_task_file_exists "$file" || continue

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

            log_info "最終報告を作成中... ($LLM_TYPE APIで処理中)"
            response=$(execute_llm "$system_prompt" "$final_task_prompt" "$(basename "$file")") || {
                log_error "$LLM_TYPE API エラー - 最終報告の作成に失敗"
                continue
            }

            echo "$response" > "$output_file"
            mark_processed "$file"
            log_success "最終報告を作成: $output_file"
            log_info "人間への報告完了 - $(basename "$output_file")"
        done

        # セッションコスト閾値チェック（超過時は自動待機）
        check_session_cost || wait_for_session_reset

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
            check_task_file_exists "$file" || continue

            log_info "新しい指示を検出: $(basename "$file")"

            local content=$(cat "$file")
            local basename=$(basename "$file" .md)

            local system_prompt=$(cat "$prompt_file" 2>/dev/null || echo "You are a PM.")

            # プロジェクトスケールに応じたセキュリティセクション
            local security_section=""
            case "${SECURITY_POLICY:-on_demand}" in
                always)
                    security_section="### SECURITY_TASK
（セキュリティエンジニアへのタスク内容）"
                    ;;
                on_demand)
                    security_section="### SECURITY_TASK
（認証・認可・権限・外部入力処理・暗号化に関わる変更がある場合のみ記載。それ以外は「該当なし」）"
                    ;;
                off)
                    security_section=""
                    ;;
            esac

            # スケール別の振り分けガイダンス
            local scale_guidance=""
            case "${PROJECT_SCALE:-small}" in
                small)
                    scale_guidance="## プロジェクト規模: ${PROJECT_SCALE} (${PROJECT_TYPE:-personal})
**タスク振り分けの厳格ルール:**
- 1つのタスクは原則 **1ロールのみ** に振ること。同じタスクを複数ロールに配布しない
- 運用タスク（見積もり改訂、パフォーマンス最適化等）はPM自身で判断し、Engineerに振らない
- デプロイは **Backendのみ** に振る（Frontend/Security/QAへの同時配布は禁止）
- QAは **機能追加・バグ修正の完了後** にのみ振る。レビューやリファクタリングでは不要
- セキュリティポリシー: ${SECURITY_POLICY} — on_demandの場合、認証・権限変更時のみSECURITY_TASKを記載
"
                    ;;
                medium)
                    scale_guidance="## プロジェクト規模: ${PROJECT_SCALE} (${PROJECT_TYPE:-team})
**タスク振り分けルール:**
- タスクは関連するロールにのみ振ること。全ロール一斉配布は原則禁止
- セキュリティポリシー: ${SECURITY_POLICY}
"
                    ;;
                large)
                    scale_guidance="## プロジェクト規模: ${PROJECT_SCALE} (${PROJECT_TYPE:-enterprise})
- セキュリティポリシー: ${SECURITY_POLICY}
"
                    ;;
            esac

            local task_prompt="${scale_guidance}以下のCEOからの指示を分析し、エンジニアへのタスクに分解してください。

## 出力形式
以下のセクションに分けて出力してください。該当タスクがない場合は「該当なし」と記載。

### FRONTEND_TASK
（フロントエンドエンジニアへのタスク内容）

### BACKEND_TASK
（バックエンドエンジニアへのタスク内容）

${security_section}

### QA_TASK
（QAへのテスト依頼。実装完了後の動作確認・リリース判定。該当なしの場合もあり）

### PO_TASK
（POへのPRレビュー依頼。EngineerがPRを作成した場合、受け入れ確認とマージを依頼。該当なしの場合もあり）

---
指示ファイル: $file
---
$content"

            local final_task_prompt
            final_task_prompt=$(build_task_prompt "$content" "$task_prompt")

            log_info "$LLM_TYPE APIで処理中..."
            response=$(execute_llm "$system_prompt" "$final_task_prompt" "$(basename "$file")") || {
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
                /^#{2,3}\s*QA[_\s-]*TASK/ { section="qa"; next }
                /^#{2,3}\s*PO[_\s-]*TASK/ { section="po"; next }
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
            for role in frontend backend security qa po; do
                if [ -f "$output_dir/${role}/${basename}-task.md" ]; then
                    log_success "タスク作成: tasks/${role}/${basename}-task.md"
                    tasks_created=true
                fi
            done

            if [ "$tasks_created" = false ]; then
                log_error "タスクファイルが作成されませんでした。LLMの出力形式を確認してください。"
                log_info "期待形式: ### FRONTEND_TASK / ### BACKEND_TASK / ### SECURITY_TASK / ### QA_TASK / ### PO_TASK"
            fi

            mark_processed "$file"
        done

        # 2. エンジニアからの報告を集約してCEOに報告
        for role in frontend backend security qa po performance_analyst; do
            local role_report_dir="$report_watch_dir/$role"
            # QA/POは専用ディレクトリに報告を書く
            if [ "$role" = "qa" ]; then
                role_report_dir="$PROJECT_DIR/shared/reports/qa"
            elif [ "$role" = "po" ]; then
                role_report_dir="$PROJECT_DIR/shared/reports/po"
            fi
            for file in "$role_report_dir"/*.md; do
                [ -f "$file" ] || continue
                is_processed "$file" && continue
                check_task_file_exists "$file" || continue

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
                response=$(execute_llm "$system_prompt" "$final_task_prompt" "$(basename "$file")") || {
                    log_error "$LLM_TYPE API エラー"
                    continue
                }

                echo "$response" > "$output_file"
                mark_processed "$file"
                log_success "CEOへ報告: $output_file"
            done
        done

        # セッションコスト閾値チェック（超過時は自動待機）
        check_session_cost || wait_for_session_reset

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
            check_task_file_exists "$file" || continue

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
            response=$(execute_llm "$system_prompt" "$final_task_prompt" "$(basename "$file")") || {
                log_error "$LLM_TYPE API エラー"
                continue
            }

            echo "$response" > "$output_file"
            mark_processed "$file"
            log_success "レポート作成: $output_file"
        done

        # セッションコスト閾値チェック（超過時は自動待機）
        check_session_cost || wait_for_session_reset

        sleep "$POLL_INTERVAL"
    done
}

# タスク完了時に見積もりと実績を突合して記録
record_task_actual() {
    local task_file="$1"    # タスクファイルのbasename (e.g. T-001-auth-foundation.md)
    local role="$2"
    local start_time="$3"   # タスク開始時刻 (epoch seconds)

    local end_time=$(date +%s)
    local actual_seconds=$(( end_time - start_time ))
    local actual_minutes=$(awk "BEGIN {printf \"%.1f\", $actual_seconds / 60}")

    local estimate_dir="$PROJECT_DIR/shared/.estimates/$role"
    local basename_noext=$(echo "$task_file" | sed 's/\.md$//')
    local estimate_file="$estimate_dir/${basename_noext}-estimate.json"
    local actual_file="$estimate_dir/${basename_noext}-actual.json"

    local est_minutes="null"
    local est_complexity="unknown"
    local description=""
    if [ -f "$estimate_file" ]; then
        est_minutes=$(jq -r '.estimated_duration_minutes // "null"' "$estimate_file" 2>/dev/null)
        est_complexity=$(jq -r '.estimated_complexity // "unknown"' "$estimate_file" 2>/dev/null)
        description=$(jq -r '.description // ""' "$estimate_file" 2>/dev/null)
    fi

    local ratio="null"
    if [ "$est_minutes" != "null" ] && [ "$est_minutes" != "0" ]; then
        ratio=$(awk "BEGIN {printf \"%.2f\", $actual_minutes / $est_minutes}")
    fi

    # usage-logからコスト・トークン情報を取得
    local usage_log="$PROJECT_DIR/shared/.usage-log.jsonl"
    local cost_usd="0"
    local total_tokens="0"
    if [ -f "$usage_log" ]; then
        cost_usd=$(jq -s --arg t "$task_file" --arg r "$role" \
            '[.[] | select(.task == $t and .role == $r) | .cost_usd // 0] | add // 0' \
            "$usage_log" 2>/dev/null || echo "0")
        total_tokens=$(jq -s --arg t "$task_file" --arg r "$role" \
            '[.[] | select(.task == $t and .role == $r) | ((.input_tokens // 0) + (.output_tokens // 0))] | add // 0' \
            "$usage_log" 2>/dev/null || echo "0")
    fi

    mkdir -p "$estimate_dir"
    cat > "$actual_file" << ACTUAL_EOF
{
  "task_file": "$task_file",
  "role": "$role",
  "completed_at": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "estimated_minutes": $est_minutes,
  "estimated_complexity": "$est_complexity",
  "actual_minutes": $actual_minutes,
  "ratio": $ratio,
  "cost_usd": $cost_usd,
  "total_tokens": $total_tokens,
  "description": "$description"
}
ACTUAL_EOF

    if [ "$est_minutes" != "null" ]; then
        log_info "実績記録: ${task_file} est=${est_minutes}m actual=${actual_minutes}m ratio=${ratio}x cost=\$${cost_usd}"
    else
        log_info "実績記録: ${task_file} actual=${actual_minutes}m cost=\$${cost_usd} (見積もりなし)"
    fi
}

# Engineerエージェント
run_engineer() {
    local role=$1
    local watch_dir="$PROJECT_DIR/shared/tasks/$role"
    local output_dir="$PROJECT_DIR/shared/reports/engineers/$role"
    local prompt_file="$PROJECT_DIR/prompts/engineers/${role}.md"

    # ロール別の作業ディレクトリを解決（worktree）
    local role_workdir
    role_workdir=$(get_role_workdir "$role")

    # QAはprompts/qa.md、reports/qa/ を使用
    if [ "$role" = "qa" ]; then
        prompt_file="$PROJECT_DIR/prompts/qa.md"
        output_dir="$PROJECT_DIR/shared/reports/qa"
    elif [ "$role" = "po" ]; then
        prompt_file="$PROJECT_DIR/prompts/po.md"
        output_dir="$PROJECT_DIR/shared/reports/po"
    fi

    validate_environment "$role" "$prompt_file"
    mkdir -p "$watch_dir" "$output_dir"

    # frontend/qa/poロールはClaude in Chrome連携を有効化（UI挙動チェック用）
    if [ "$role" = "frontend" ] || [ "$role" = "qa" ] || [ "$role" = "po" ]; then
        export ENABLE_CHROME=1
        log_info "$role Agent 起動 - 監視: $watch_dir, 作業: $role_workdir (Chrome連携: 有効)"
    else
        unset ENABLE_CHROME
        log_info "$role Agent 起動 - 監視: $watch_dir, 作業: $role_workdir"
    fi

    while true; do
        for file in "$watch_dir"/*.md; do
            [ -f "$file" ] || continue
            is_processed "$file" && continue
            check_task_file_exists "$file" || continue

            log_info "新しいタスクを検出: $(basename "$file")"

            local task_start_time=$(date +%s)
            local content=$(cat "$file")
            local basename=$(basename "$file" .md)
            local output_file="$output_dir/${basename}-report.md"

            local system_prompt=$(cat "$prompt_file" 2>/dev/null || echo "You are a $role engineer.")

            # 事前見積もり指示（Performance Analyst が分析に使用）
            local estimate_dir="$PROJECT_DIR/shared/.estimates/$role"
            mkdir -p "$estimate_dir"
            local estimate_instruction="## 事前見積もり（必須・最初に実行）
タスクの内容を確認し、作業を開始する前に以下のJSONファイルを作成してください。
ファイルパス: $estimate_dir/${basename}-estimate.json

\`\`\`json
{
  \"task_file\": \"$(basename "$file")\",
  \"role\": \"$role\",
  \"estimated_at\": \"$(date -u '+%Y-%m-%dT%H:%M:%SZ')\",
  \"estimated_duration_minutes\": <見積もり時間（分）>,
  \"estimated_complexity\": \"<low/medium/high>\",
  \"description\": \"<タスクの一行要約>\",
  \"subtasks\": [\"<サブタスク1>\", \"<サブタスク2>\"]
}
\`\`\`

見積もりファイル作成後、以下の本タスクを実行してください。

---

"
            local task_prompt=""

            if [ "$role" = "qa" ]; then
                task_prompt="${estimate_instruction}以下のテスト依頼を実施し、結果を報告してください。

## 作業ディレクトリ
$role_workdir

## ブランチ切り替え
タスク内容にPR URLやブランチ名が含まれている場合は、そのブランチをチェックアウトしてテストすること。
\`\`\`bash
cd $role_workdir
git fetch origin
git checkout <feature-branch-name>
\`\`\`

## テスト手順（必須）
1. プロジェクト構造を確認し、Playwrightのセットアップ状態を確認する
2. Playwrightが未導入なら初期セットアップを行う（npm install -D @playwright/test && npx playwright install --with-deps chromium）
3. テスト依頼の内容に基づき、Playwright E2Eテストを作成する（tests/e2e/*.spec.ts）
4. 開発サーバーを起動し、npx playwright test を実行する
5. テストが失敗した場合、Claude in Chrome（ブラウザツール）で該当ページを開き、探索的にデバッグする
   - スクリーンショットで画面表示を確認
   - コンソールエラーの確認（read_console_messages）
   - UI操作で再現確認
6. テスト結果をまとめ、リリース判定（GO/NO-GO/CONDITIONAL）を行う
7. 発見したバグは再現手順付きで報告する

タスクファイル: $file
---
$content"
            elif [ "$role" = "po" ]; then
                task_prompt="${estimate_instruction}以下のPRレビュー依頼を処理してください。

## 作業ディレクトリ
$role_workdir

## レビュー手順（必須）
1. PR URLからPR番号を抽出
2. \`gh pr view <番号>\` でPR詳細を取得
3. \`gh pr diff <番号>\` で変更内容を確認
4. 受け入れ基準を確認し、変更が要件を満たしているか判断
5. 必要に応じて、PRのブランチをチェックアウトして動作確認
   \`\`\`bash
   cd $role_workdir
   gh pr checkout <番号>
   \`\`\`
6. ブラウザで動作確認（Claude in Chromeツール使用）
   - 開発サーバーが起動していなければ起動する
   - スクリーンショットで表示を確認
   - コンソールエラーがないか確認
7. 判断:
   - 問題なし → \`gh pr merge <番号> --squash\` でマージ
   - 軽微な問題/判断困難 → \`gh pr comment <番号> --body \"...\"\` でフィードバック
   - ブロッキング問題 → \`gh pr review <番号> --request-changes --body \"...\"\`
8. PMへ結果を報告

タスクファイル: $file
---
$content"
            else
                task_prompt="${estimate_instruction}以下のタスクを実行し、結果を報告してください。

## 作業ディレクトリ
$role_workdir

## Git運用ルール（必須）
1. 作業ディレクトリ \`$role_workdir\` で作業すること
2. 作業前に \`${WORKTREE_BASE_BRANCH}\` ブランチの最新を取り込み、feature/ または fix/ ブランチを作成すること
   \`\`\`bash
   cd $role_workdir
   git fetch origin
   git checkout -b feature/{タスクID}-{簡潔な説明} origin/${WORKTREE_BASE_BRANCH}
   \`\`\`
   - 新機能: \`feature/{タスクID}-{簡潔な説明}\`（例: \`feature/T-001-auth-foundation\`）
   - バグ修正: \`fix/{タスクID}-{簡潔な説明}\`（例: \`fix/T-001-jwt-token-error\`）
3. 作業はfeature/fixブランチで行い、${WORKTREE_BASE_BRANCH}には直接コミットしないこと
4. 作業完了後、\`gh pr create --base ${WORKTREE_BASE_BRANCH}\` で${WORKTREE_BASE_BRANCH}ブランチへのPull Requestを作成すること
5. PRのタイトルにタスクIDを含めること
6. PR作成後、ブランチはそのまま残すこと（${WORKTREE_BASE_BRANCH}にcheckoutしないこと）

タスクファイル: $file
---
$content"
            fi

            local final_task_prompt
            final_task_prompt=$(build_task_prompt "$content" "$task_prompt")

            log_info "$LLM_TYPE APIで処理中..."

            # ウォッチドッグ: 長時間タスクの経過を定期表示（5分ごと）
            local watchdog_pid=""
            local _wd_file
            _wd_file="$(basename "$file")"
            (
                wd_start=$(date +%s)
                while true; do
                    sleep 300  # 5分ごと
                    wd_elapsed=$(( ($(date +%s) - wd_start) / 60 ))
                    echo -e "\033[2m$(date '+%H:%M:%S')\033[0m \033[0;33m[WARN]\033[0m タスク処理中: $_wd_file — ${wd_elapsed}分経過"
                done
            ) &
            watchdog_pid=$!

            response=$(execute_llm "$system_prompt" "$final_task_prompt" "$(basename "$file")" "$role_workdir") || {
                kill "$watchdog_pid" 2>/dev/null; wait "$watchdog_pid" 2>/dev/null
                log_error "$LLM_TYPE API エラー"
                continue
            }

            # ウォッチドッグ停止
            kill "$watchdog_pid" 2>/dev/null; wait "$watchdog_pid" 2>/dev/null

            echo "$response" > "$output_file"
            mark_processed "$file"
            record_task_actual "$(basename "$file")" "$role" "$task_start_time"
            log_success "レポート作成: $output_file"
        done

        # セッションコスト閾値チェック（超過時は自動待機）
        check_session_cost || wait_for_session_reset

        sleep "$POLL_INTERVAL"
    done
}

# Performance Analyst エージェント（タイマー駆動）
run_performance_analyst() {
    local output_dir="$PROJECT_DIR/shared/reports/engineers/performance_analyst"
    local estimate_dir="$PROJECT_DIR/shared/.estimates"
    local usage_log="$PROJECT_DIR/shared/.usage-log.jsonl"
    local prompt_file="$PROJECT_DIR/prompts/performance_analyst.md"
    local check_interval="$PERF_ANALYST_INTERVAL"
    local last_line_count=0

    validate_environment "performance_analyst" "$prompt_file"
    mkdir -p "$output_dir" "$estimate_dir"

    log_info "Performance Analyst Agent 起動 - オンデマンド実行（1回分析）"

    # オンデマンドモード: ループせず1回だけ実行
    {

        # 2. 直近5時間のサマリーをjqで事前集計
        local five_hours_ago
        five_hours_ago=$(date -u -d '5 hours ago' '+%Y-%m-%dT%H:%M:%SZ')

        local usage_summary=""
        if [ -f "$usage_log" ]; then
            usage_summary=$(jq -s --arg since "$five_hours_ago" '
                [.[] | select(.timestamp >= $since)] |
                {
                    total_entries: length,
                    total_cost: (map(.cost_usd // 0) | add // 0),
                    total_input_tokens: (map(.input_tokens // 0) | add // 0),
                    total_output_tokens: (map(.output_tokens // 0) | add // 0),
                    by_role: (group_by(.role) | map({
                        role: .[0].role,
                        count: length,
                        cost: (map(.cost_usd // 0) | add // 0),
                        input_tokens: (map(.input_tokens // 0) | add // 0),
                        output_tokens: (map(.output_tokens // 0) | add // 0),
                        avg_duration_ms: ((map(.duration_ms // 0) | add // 0) / length)
                    }))
                }
            ' "$usage_log" 2>/dev/null)
        fi

        # 3. 超過タスクの検出（見積もりと実績を突合）
        local overrun_info=""
        if [ -d "$estimate_dir" ] && [ -f "$usage_log" ]; then
            overrun_info=$(find "$estimate_dir" -name '*-estimate.json' -exec sh -c '
                usage_log="$1"; shift
                for f do
                    task=$(jq -r ".task_file // empty" "$f" 2>/dev/null) || continue
                    est_min=$(jq -r ".estimated_duration_minutes // empty" "$f" 2>/dev/null) || continue
                    role=$(jq -r ".role // empty" "$f" 2>/dev/null) || continue
                    [ -z "$task" ] || [ -z "$est_min" ] || [ -z "$role" ] && continue
                    [ "$est_min" = "0" ] && continue

                    actual_ms=$(jq -s --arg t "$task" --arg r "$role" \
                        "[.[] | select(.task == \$t and .role == \$r) | .duration_ms // 0] | add // 0" \
                        "$usage_log" 2>/dev/null)
                    [ -z "$actual_ms" ] || [ "$actual_ms" = "0" ] && continue

                    actual_min=$(echo "$actual_ms" | awk "{printf \"%.1f\", \$1/60000}")
                    ratio=$(echo "$actual_min $est_min" | awk "{if (\$2>0) printf \"%.2f\", \$1/\$2; else print \"0\"}")
                    is_over=$(echo "$ratio" | awk "{print (\$1 >= 1.5) ? 1 : 0}")

                    if [ "$is_over" = "1" ]; then
                        desc=$(jq -r ".description // \"\"" "$f" 2>/dev/null)
                        echo "- task=$task role=$role est=${est_min}m actual=${actual_min}m ratio=${ratio}x desc=\"$desc\""
                    fi
                done
            ' _ "$usage_log" {} + 2>/dev/null)
        fi

        # 4. 完了タスクの見積もりvs実績サマリー（*-actual.json から集計）
        local actuals_summary=""
        if [ -d "$estimate_dir" ]; then
            actuals_summary=$(find "$estimate_dir" -name '*-actual.json' -exec cat {} + 2>/dev/null | jq -s '
                if length == 0 then {total: 0, tasks: []}
                else {
                    total: length,
                    avg_ratio: (map(select(.ratio != null) | .ratio) | if length > 0 then (add / length) else null end),
                    total_cost: (map(.cost_usd // 0) | add),
                    by_role: (group_by(.role) | map({
                        role: .[0].role,
                        count: length,
                        avg_estimated_min: (map(select(.estimated_minutes != null) | .estimated_minutes) | if length > 0 then (add / length) else null end),
                        avg_actual_min: (map(.actual_minutes) | add / length),
                        avg_ratio: (map(select(.ratio != null) | .ratio) | if length > 0 then (add / length) else null end),
                        total_cost: (map(.cost_usd // 0) | add)
                    })),
                    tasks: map({
                        task: .task_file,
                        role: .role,
                        est: .estimated_minutes,
                        actual: .actual_minutes,
                        ratio: .ratio,
                        cost: .cost_usd
                    })
                }
                end
            ' 2>/dev/null)
        fi

        # 5. LLMに分析を依頼
        local system_prompt
        system_prompt=$(cat "$prompt_file" 2>/dev/null || echo "You are a performance analyst.")

        local task_prompt="以下のデータを分析し、レポートを作成してください。

## Usage Summary (直近5時間, since $five_hours_ago)
\`\`\`json
${usage_summary:-{}}
\`\`\`

## 超過タスク（見積もりの1.5倍超過）
${overrun_info:-なし}

## 完了タスク実績（見積もり vs 実績）
\`\`\`json
${actuals_summary:-{\"total\": 0}}
\`\`\`

## 分析指示
1. ロール別コスト効率を評価してください
2. 超過タスクがあれば原因を推測し、改善策を提案してください
3. **見積もり精度を評価してください**（ratio=actual/estimated, 1.0が理想。ratio < 0.5 は過大見積もり、ratio > 1.5 は過小見積もり）
4. ロール別に見積もり傾向（過大/過小/適正）を分析し、改善提案してください
5. モデル選択の妥当性を検証してください（model_usage フィールドを参照）
6. キャッシュ効率（cache_read vs cache_creation の比率）を評価してください
7. 全体的な改善提案をまとめてください

レポートは [REPORT TO: PM] フォーマットで出力してください。"

        local final_task_prompt
        final_task_prompt=$(build_task_prompt "" "$task_prompt")

        log_info "分析実行中..."
        local response
        response=$(execute_llm "$system_prompt" "$final_task_prompt" "periodic-analysis") || {
            log_error "分析APIエラー"
            sleep "$check_interval"
            continue
        }

        local timestamp
        timestamp=$(date '+%Y%m%d-%H%M%S')
        echo "$response" > "$output_dir/analysis-${timestamp}-report.md"
        log_success "分析レポート作成: analysis-${timestamp}-report.md"

        log_success "分析完了"
    }
}

# メイン
main() {
    local role=${1:-}
    local llm_type=${2:-claude}

    # LLMタイプとロール名を環境変数に設定
    export LLM_TYPE="$llm_type"
    export CURRENT_ROLE="$role"

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
        frontend|backend|security|qa|po)
            run_engineer "$role"
            ;;
        performance_analyst)
            run_performance_analyst
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
