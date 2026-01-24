#!/bin/bash

# agent-corp 監視・ログスクリプト
# エージェントの活動をリアルタイムで監視し、ログを収集する

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SHARED_DIR="$PROJECT_DIR/shared"
LOG_DIR="$SHARED_DIR/logs"

# 色付きログ
log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[OK]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; }
log_warn() { echo -e "\033[0;33m[WARN]\033[0m $1"; }

# 使用方法
usage() {
    cat << EOF
Usage: $0 <COMMAND> [OPTIONS]

Commands:
    dashboard   リアルタイムダッシュボードを表示
    status      現在のシステム状態を表示
    log         アクティビティログを表示
    stats       統計情報を表示
    export      ログをエクスポート
    help        このヘルプを表示

Dashboard Options:
    --refresh <sec>    更新間隔 [default: 2]

Log Options:
    --tail <n>         最新n件を表示 [default: 20]
    --follow           リアルタイムで追跡

Export Options:
    --output <file>    出力ファイル [default: agent-corp-log-YYYYMMDD.json]
    --format <fmt>     フォーマット (json|csv|md) [default: json]

Examples:
    $0 dashboard                    # リアルタイムダッシュボード
    $0 status                       # 現在の状態
    $0 log --tail 50 --follow       # ログをリアルタイム追跡
    $0 stats                        # 統計情報
    $0 export --format md           # Markdownでエクスポート

EOF
}

# メッセージ数をカウント
count_messages() {
    local dir="$1"
    local status="$2"

    if [ -z "$status" ]; then
        find "$dir" -name "*.md" -type f 2>/dev/null | wc -l
    else
        find "$dir" -name "*.md" -type f -exec grep -l "status: $status" {} \; 2>/dev/null | wc -l
    fi
}

# ダッシュボード表示
show_dashboard() {
    local refresh=${1:-2}

    while true; do
        clear
        echo "========================================"
        echo "  agent-corp Dashboard"
        echo "  $(date '+%Y-%m-%d %H:%M:%S')"
        echo "========================================"
        echo ""

        # メッセージ統計
        echo "📊 メッセージ統計"
        echo "──────────────────────────────────────"
        printf "  %-20s %s\n" "要件 (requirements):" "$(count_messages "$SHARED_DIR/requirements")"
        printf "  %-20s %s\n" "指示 (instructions):" "$(count_messages "$SHARED_DIR/instructions/pm")"
        printf "  %-20s %s\n" "タスク (tasks):" "$(($(count_messages "$SHARED_DIR/tasks/frontend") + $(count_messages "$SHARED_DIR/tasks/backend") + $(count_messages "$SHARED_DIR/tasks/security")))"
        printf "  %-20s %s\n" "報告 (reports):" "$(($(count_messages "$SHARED_DIR/reports/engineers/frontend") + $(count_messages "$SHARED_DIR/reports/engineers/backend") + $(count_messages "$SHARED_DIR/reports/engineers/security") + $(count_messages "$SHARED_DIR/reports/pm") + $(count_messages "$SHARED_DIR/reports/human")))"
        printf "  %-20s %s\n" "質問 (questions):" "$(find "$SHARED_DIR/questions" -name "*.md" -type f 2>/dev/null | wc -l)"
        echo ""

        # ステータス別
        echo "📋 ステータス別"
        echo "──────────────────────────────────────"
        local pending=$(find "$SHARED_DIR" -name "*.md" -type f -exec grep -l "status: pending" {} \; 2>/dev/null | wc -l)
        local in_progress=$(find "$SHARED_DIR" -name "*.md" -type f -exec grep -l "status: in_progress" {} \; 2>/dev/null | wc -l)
        local completed=$(find "$SHARED_DIR" -name "*.md" -type f -exec grep -l "status: completed" {} \; 2>/dev/null | wc -l)
        local blocked=$(find "$SHARED_DIR" -name "*.md" -type f -exec grep -l "status: blocked" {} \; 2>/dev/null | wc -l)

        printf "  \033[0;33m●\033[0m Pending:     %d\n" "$pending"
        printf "  \033[0;34m●\033[0m In Progress: %d\n" "$in_progress"
        printf "  \033[0;32m●\033[0m Completed:   %d\n" "$completed"
        printf "  \033[0;31m●\033[0m Blocked:     %d\n" "$blocked"
        echo ""

        # 最新のアクティビティ
        echo "📝 最新のアクティビティ (5件)"
        echo "──────────────────────────────────────"
        find "$SHARED_DIR" -name "*.md" -type f -printf "%T@ %p\n" 2>/dev/null |
            sort -rn | head -5 |
            while read timestamp file; do
                local filename=$(basename "$file")
                local title=$(grep "^# " "$file" 2>/dev/null | head -1 | sed 's/^# //')
                local time=$(date -d "@${timestamp%.*}" '+%H:%M:%S' 2>/dev/null || echo "??:??:??")
                printf "  %s  %-25s %s\n" "$time" "$filename" "${title:0:30}"
            done
        echo ""

        # タスク別進捗
        echo "👥 Engineer別タスク"
        echo "──────────────────────────────────────"
        for engineer in frontend backend security; do
            local total=$(count_messages "$SHARED_DIR/tasks/$engineer")
            local done=$(count_messages "$SHARED_DIR/reports/engineers/$engineer")
            printf "  %-12s タスク: %d, 完了: %d\n" "$engineer:" "$total" "$done"
        done
        echo ""

        echo "──────────────────────────────────────"
        echo "  Ctrl+C で終了 | 更新間隔: ${refresh}秒"

        sleep "$refresh"
    done
}

# 現在の状態を表示
show_status() {
    echo "========================================"
    echo "  agent-corp Status"
    echo "========================================"
    echo ""

    echo "📁 共有ディレクトリ: $SHARED_DIR"
    echo ""

    # 各ディレクトリの状態
    echo "📊 ディレクトリ別ファイル数"
    echo "──────────────────────────────────────"

    for dir in requirements instructions/pm tasks/frontend tasks/backend tasks/security \
               reports/engineers/frontend reports/engineers/backend reports/engineers/security \
               reports/pm reports/human; do
        local count=$(count_messages "$SHARED_DIR/$dir")
        printf "  %-35s %d\n" "$dir:" "$count"
    done
    echo ""

    # Pending メッセージ
    echo "⏳ 未処理メッセージ (pending)"
    echo "──────────────────────────────────────"
    find "$SHARED_DIR" -name "*.md" -type f -exec grep -l "status: pending" {} \; 2>/dev/null |
        while read file; do
            local filename=$(basename "$file")
            local dir=$(dirname "$file" | sed "s|$SHARED_DIR/||")
            printf "  %-20s %s\n" "$dir:" "$filename"
        done
    echo ""

    # Blocked メッセージ
    local blocked_count=$(find "$SHARED_DIR" -name "*.md" -type f -exec grep -l "status: blocked" {} \; 2>/dev/null | wc -l)
    if [ "$blocked_count" -gt 0 ]; then
        echo "🚫 ブロック中メッセージ (blocked)"
        echo "──────────────────────────────────────"
        find "$SHARED_DIR" -name "*.md" -type f -exec grep -l "status: blocked" {} \; 2>/dev/null |
            while read file; do
                local filename=$(basename "$file")
                local dir=$(dirname "$file" | sed "s|$SHARED_DIR/||")
                printf "  %-20s %s\n" "$dir:" "$filename"
            done
        echo ""
    fi
}

# ログ表示
show_log() {
    local tail_count=20
    local follow=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --tail) tail_count="$2"; shift 2 ;;
            --follow) follow=true; shift ;;
            *) shift ;;
        esac
    done

    echo "📝 アクティビティログ (最新 $tail_count 件)"
    echo "========================================"
    echo ""

    if [ "$follow" = true ]; then
        # リアルタイム追跡
        local last_check=$(mktemp)
        touch "$last_check"

        while true; do
            find "$SHARED_DIR" -name "*.md" -type f -newer "$last_check" 2>/dev/null |
                while read file; do
                    local filename=$(basename "$file")
                    local from=$(grep "^from:" "$file" 2>/dev/null | cut -d: -f2 | tr -d ' ')
                    local to=$(grep "^to:" "$file" 2>/dev/null | cut -d: -f2 | tr -d ' ')
                    local type=$(grep "^type:" "$file" 2>/dev/null | cut -d: -f2 | tr -d ' ')
                    local title=$(grep "^# " "$file" 2>/dev/null | head -1 | sed 's/^# //')
                    local time=$(date '+%H:%M:%S')

                    printf "%s  %-8s → %-8s  [%-12s]  %s\n" "$time" "$from" "$to" "$type" "${title:0:40}"
                done

            touch "$last_check"
            sleep 1
        done
    else
        # 静的表示
        find "$SHARED_DIR" -name "*.md" -type f -printf "%T@ %p\n" 2>/dev/null |
            sort -rn | head -"$tail_count" |
            while read timestamp file; do
                local filename=$(basename "$file")
                local from=$(grep "^from:" "$file" 2>/dev/null | cut -d: -f2 | tr -d ' ')
                local to=$(grep "^to:" "$file" 2>/dev/null | cut -d: -f2 | tr -d ' ')
                local type=$(grep "^type:" "$file" 2>/dev/null | cut -d: -f2 | tr -d ' ')
                local status=$(grep "^status:" "$file" 2>/dev/null | cut -d: -f2 | tr -d ' ')
                local title=$(grep "^# " "$file" 2>/dev/null | head -1 | sed 's/^# //')
                local time=$(date -d "@${timestamp%.*}" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "????-??-?? ??:??:??")

                printf "%s  %-8s → %-8s  [%-12s]  %-10s  %s\n" "$time" "$from" "$to" "$type" "$status" "${title:0:30}"
            done
    fi
}

# 統計情報
show_stats() {
    echo "========================================"
    echo "  agent-corp 統計情報"
    echo "========================================"
    echo ""

    local total=$(find "$SHARED_DIR" -name "*.md" -type f 2>/dev/null | wc -l)
    local pending=$(find "$SHARED_DIR" -name "*.md" -type f -exec grep -l "status: pending" {} \; 2>/dev/null | wc -l)
    local in_progress=$(find "$SHARED_DIR" -name "*.md" -type f -exec grep -l "status: in_progress" {} \; 2>/dev/null | wc -l)
    local completed=$(find "$SHARED_DIR" -name "*.md" -type f -exec grep -l "status: completed" {} \; 2>/dev/null | wc -l)
    local blocked=$(find "$SHARED_DIR" -name "*.md" -type f -exec grep -l "status: blocked" {} \; 2>/dev/null | wc -l)

    echo "📊 全体統計"
    echo "──────────────────────────────────────"
    printf "  %-20s %d\n" "総メッセージ数:" "$total"
    printf "  %-20s %d (%.1f%%)\n" "Pending:" "$pending" "$(echo "scale=1; $pending * 100 / ($total + 1)" | bc)"
    printf "  %-20s %d (%.1f%%)\n" "In Progress:" "$in_progress" "$(echo "scale=1; $in_progress * 100 / ($total + 1)" | bc)"
    printf "  %-20s %d (%.1f%%)\n" "Completed:" "$completed" "$(echo "scale=1; $completed * 100 / ($total + 1)" | bc)"
    printf "  %-20s %d (%.1f%%)\n" "Blocked:" "$blocked" "$(echo "scale=1; $blocked * 100 / ($total + 1)" | bc)"
    echo ""

    echo "📈 優先度別"
    echo "──────────────────────────────────────"
    for priority in critical high medium low; do
        local count=$(find "$SHARED_DIR" -name "*.md" -type f -exec grep -l "priority: $priority" {} \; 2>/dev/null | wc -l)
        printf "  %-20s %d\n" "$priority:" "$count"
    done
    echo ""

    echo "📁 メッセージタイプ別"
    echo "──────────────────────────────────────"
    for type in requirement instruction task report question answer; do
        local count=$(find "$SHARED_DIR" -name "*.md" -type f -exec grep -l "type: $type" {} \; 2>/dev/null | wc -l)
        printf "  %-20s %d\n" "$type:" "$count"
    done
    echo ""

    echo "👥 エージェント別送信数"
    echo "──────────────────────────────────────"
    for agent in human ceo pm frontend backend security; do
        local count=$(find "$SHARED_DIR" -name "*.md" -type f -exec grep -l "from: $agent" {} \; 2>/dev/null | wc -l)
        printf "  %-20s %d\n" "$agent:" "$count"
    done
}

# ログエクスポート
export_log() {
    local output=""
    local format="json"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --output) output="$2"; shift 2 ;;
            --format) format="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [ -z "$output" ]; then
        output="agent-corp-log-$(date +%Y%m%d).$format"
    fi

    log_info "ログをエクスポート中: $output"

    case $format in
        json)
            echo "[" > "$output"
            local first=true
            find "$SHARED_DIR" -name "*.md" -type f -printf "%T@ %p\n" 2>/dev/null |
                sort -rn |
                while read timestamp file; do
                    if [ "$first" = true ]; then
                        first=false
                    else
                        echo "," >> "$output"
                    fi

                    local id=$(grep "^id:" "$file" 2>/dev/null | cut -d: -f2 | tr -d ' ')
                    local from=$(grep "^from:" "$file" 2>/dev/null | cut -d: -f2 | tr -d ' ')
                    local to=$(grep "^to:" "$file" 2>/dev/null | cut -d: -f2 | tr -d ' ')
                    local type=$(grep "^type:" "$file" 2>/dev/null | cut -d: -f2 | tr -d ' ')
                    local status=$(grep "^status:" "$file" 2>/dev/null | cut -d: -f2 | tr -d ' ')
                    local priority=$(grep "^priority:" "$file" 2>/dev/null | cut -d: -f2 | tr -d ' ')
                    local title=$(grep "^# " "$file" 2>/dev/null | head -1 | sed 's/^# //' | sed 's/"/\\"/g')

                    cat >> "$output" << EOF
  {
    "id": "$id",
    "file": "$(basename "$file")",
    "from": "$from",
    "to": "$to",
    "type": "$type",
    "status": "$status",
    "priority": "$priority",
    "title": "$title"
  }
EOF
                done
            echo "]" >> "$output"
            ;;
        csv)
            echo "id,file,from,to,type,status,priority,title" > "$output"
            find "$SHARED_DIR" -name "*.md" -type f 2>/dev/null |
                while read file; do
                    local id=$(grep "^id:" "$file" 2>/dev/null | cut -d: -f2 | tr -d ' ')
                    local from=$(grep "^from:" "$file" 2>/dev/null | cut -d: -f2 | tr -d ' ')
                    local to=$(grep "^to:" "$file" 2>/dev/null | cut -d: -f2 | tr -d ' ')
                    local type=$(grep "^type:" "$file" 2>/dev/null | cut -d: -f2 | tr -d ' ')
                    local status=$(grep "^status:" "$file" 2>/dev/null | cut -d: -f2 | tr -d ' ')
                    local priority=$(grep "^priority:" "$file" 2>/dev/null | cut -d: -f2 | tr -d ' ')
                    local title=$(grep "^# " "$file" 2>/dev/null | head -1 | sed 's/^# //' | sed 's/,/;/g')

                    echo "$id,$(basename "$file"),$from,$to,$type,$status,$priority,$title" >> "$output"
                done
            ;;
        md)
            cat > "$output" << EOF
# agent-corp ログ

エクスポート日時: $(date '+%Y-%m-%d %H:%M:%S')

## メッセージ一覧

| ID | ファイル | From | To | Type | Status | Priority | Title |
|----|---------:|------|---:|------|--------|----------|-------|
EOF
            find "$SHARED_DIR" -name "*.md" -type f -printf "%T@ %p\n" 2>/dev/null |
                sort -rn |
                while read timestamp file; do
                    local id=$(grep "^id:" "$file" 2>/dev/null | cut -d: -f2 | tr -d ' ')
                    local from=$(grep "^from:" "$file" 2>/dev/null | cut -d: -f2 | tr -d ' ')
                    local to=$(grep "^to:" "$file" 2>/dev/null | cut -d: -f2 | tr -d ' ')
                    local type=$(grep "^type:" "$file" 2>/dev/null | cut -d: -f2 | tr -d ' ')
                    local status=$(grep "^status:" "$file" 2>/dev/null | cut -d: -f2 | tr -d ' ')
                    local priority=$(grep "^priority:" "$file" 2>/dev/null | cut -d: -f2 | tr -d ' ')
                    local title=$(grep "^# " "$file" 2>/dev/null | head -1 | sed 's/^# //')

                    echo "| ${id:0:8}... | $(basename "$file") | $from | $to | $type | $status | $priority | ${title:0:30} |" >> "$output"
                done
            ;;
        *)
            log_error "不明なフォーマット: $format"
            exit 1
            ;;
    esac

    log_success "エクスポート完了: $output"
}

# メイン処理
main() {
    local command=${1:-help}
    shift || true

    case $command in
        dashboard)
            local refresh=2
            while [[ $# -gt 0 ]]; do
                case $1 in
                    --refresh) refresh="$2"; shift 2 ;;
                    *) shift ;;
                esac
            done
            show_dashboard "$refresh"
            ;;
        status)
            show_status
            ;;
        log)
            show_log "$@"
            ;;
        stats)
            show_stats
            ;;
        export)
            export_log "$@"
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            log_error "不明なコマンド: $command"
            usage
            exit 1
            ;;
    esac
}

main "$@"
