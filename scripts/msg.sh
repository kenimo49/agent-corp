#!/bin/bash

# agent-corp メッセージ管理スクリプト
# エージェント間のメッセージ作成・送信・監視を行う

set -e

SHARED_DIR="${SHARED_DIR:-./shared}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

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
    send        メッセージを送信
    list        メッセージ一覧を表示
    read        メッセージを読み取り
    status      メッセージのステータスを更新
    watch       新着メッセージを監視
    reset       全未処理タスクを処理済みにマーク（クリーンリセット）
    help        このヘルプを表示

Send Options:
    --from <agent>      送信元 (human|ceo|pm|frontend|backend|security)
    --to <agent>        宛先
    --type <type>       メッセージタイプ (requirement|instruction|task|report|question|answer)
    --priority <pri>    優先度 (critical|high|medium|low) [default: medium]
    --title <title>     タイトル
    --body <body>       本文（または --file で指定）
    --file <file>       本文を読み込むファイル
    --parent <id>       親メッセージID

List Options:
    --dir <directory>   対象ディレクトリ
    --status <status>   フィルタ (pending|in_progress|completed|blocked)
    --limit <n>         表示件数 [default: 10]

Watch Options:
    --dir <directory>   監視対象ディレクトリ
    --interval <sec>    ポーリング間隔 [default: 5]

Examples:
    # 要件を送信
    $0 send --from human --to ceo --type requirement \\
        --title "ログイン機能の実装" --body "ユーザー認証機能を追加してください"

    # PMへのタスク一覧
    $0 list --dir tasks/frontend --status pending

    # 新着メッセージを監視
    $0 watch --dir tasks/backend

    # 全未処理タスクをリセット（新しい依頼前に実行）
    $0 reset

    # ドライランで対象件数を確認
    $0 reset --dry-run

EOF
}

# ULID風のID生成（簡易版）
generate_id() {
    local timestamp=$(date +%s%N | cut -c1-13)
    local random=$(cat /dev/urandom | tr -dc 'A-Z0-9' | fold -w 10 | head -n 1)
    echo "${timestamp}${random}"
}

# 日付ベースのタスクID生成
generate_task_id() {
    local type=$1
    local date=$(date +%Y%m%d)
    local seq=$(find "$SHARED_DIR" -name "${date}-*-${type}.md" 2>/dev/null | wc -l)
    seq=$((seq + 1))
    printf "%s-%03d-%s" "$date" "$seq" "$type"
}

# メッセージタイプから保存先ディレクトリを決定
get_message_dir() {
    local from=$1
    local to=$2
    local type=$3

    case $type in
        requirement)
            echo "requirements"
            ;;
        instruction)
            echo "instructions/$to"
            ;;
        task)
            echo "tasks/$to"
            ;;
        report)
            if [ "$from" = "pm" ]; then
                echo "reports/pm"
            elif [ "$from" = "ceo" ]; then
                echo "reports/human"
            else
                echo "reports/engineers/$from"
            fi
            ;;
        question)
            echo "questions/${from}-to-${to}"
            ;;
        answer)
            echo "questions/answers"
            ;;
        *)
            log_error "不明なメッセージタイプ: $type"
            exit 1
            ;;
    esac
}

# メッセージタイプの略称
get_type_abbrev() {
    case $1 in
        requirement) echo "req" ;;
        instruction) echo "inst" ;;
        task) echo "task" ;;
        report) echo "rep" ;;
        question) echo "q" ;;
        answer) echo "a" ;;
        *) echo "msg" ;;
    esac
}

# メッセージ送信
send_message() {
    local from="" to="" type="" priority="medium" title="" body="" file="" parent=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --from) from="$2"; shift 2 ;;
            --to) to="$2"; shift 2 ;;
            --type) type="$2"; shift 2 ;;
            --priority) priority="$2"; shift 2 ;;
            --title) title="$2"; shift 2 ;;
            --body) body="$2"; shift 2 ;;
            --file) file="$2"; shift 2 ;;
            --parent) parent="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    # バリデーション
    if [ -z "$from" ] || [ -z "$to" ] || [ -z "$type" ] || [ -z "$title" ]; then
        log_error "必須パラメータが不足しています: --from, --to, --type, --title"
        exit 1
    fi

    # 本文の取得
    if [ -n "$file" ] && [ -f "$file" ]; then
        body=$(cat "$file")
    elif [ -z "$body" ]; then
        log_error "本文が指定されていません: --body または --file"
        exit 1
    fi

    # ID生成
    local id=$(generate_id)
    local task_id=$(generate_task_id "$(get_type_abbrev $type)")
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # 保存先ディレクトリ
    local dir=$(get_message_dir "$from" "$to" "$type")
    local filepath="$SHARED_DIR/$dir/${task_id}.md"

    # ディレクトリ作成
    mkdir -p "$SHARED_DIR/$dir"

    # 親メッセージID行
    local parent_line=""
    if [ -n "$parent" ]; then
        parent_line="parent_id: $parent"
    fi

    # メッセージ作成
    cat > "$filepath" << EOF
---
id: $id
from: $from
to: $to
type: $type
priority: $priority
status: pending
created_at: $timestamp
updated_at: $timestamp
${parent_line}
---

# ${title}

${body}
EOF

    log_success "メッセージを送信しました: $filepath"
    echo "ID: $task_id"
}

# メッセージ一覧
list_messages() {
    local dir="" status="" limit=10

    while [[ $# -gt 0 ]]; do
        case $1 in
            --dir) dir="$2"; shift 2 ;;
            --status) status="$2"; shift 2 ;;
            --limit) limit="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [ -z "$dir" ]; then
        log_error "--dir が指定されていません"
        exit 1
    fi

    local target="$SHARED_DIR/$dir"
    if [ ! -d "$target" ]; then
        log_error "ディレクトリが存在しません: $target"
        exit 1
    fi

    echo "=== メッセージ一覧: $dir ==="
    echo ""

    local count=0
    for file in $(find "$target" -name "*.md" -type f | sort -r); do
        if [ $count -ge $limit ]; then
            break
        fi

        # ステータスフィルタ
        if [ -n "$status" ]; then
            if ! grep -q "status: $status" "$file" 2>/dev/null; then
                continue
            fi
        fi

        local filename=$(basename "$file")
        local file_status=$(grep "^status:" "$file" 2>/dev/null | cut -d: -f2 | tr -d ' ')
        local file_priority=$(grep "^priority:" "$file" 2>/dev/null | cut -d: -f2 | tr -d ' ')
        local file_title=$(grep "^# " "$file" 2>/dev/null | head -1 | sed 's/^# //')

        # ステータスに応じた色
        case $file_status in
            pending) status_color="\033[0;33m" ;;
            in_progress) status_color="\033[0;34m" ;;
            completed) status_color="\033[0;32m" ;;
            blocked) status_color="\033[0;31m" ;;
            *) status_color="\033[0m" ;;
        esac

        printf "${status_color}[%s]\033[0m %s - %s\n" "$file_status" "$filename" "$file_title"
        count=$((count + 1))
    done

    if [ $count -eq 0 ]; then
        echo "メッセージがありません"
    else
        echo ""
        echo "合計: $count 件"
    fi
}

# メッセージ読み取り
read_message() {
    local file="$1"

    if [ -z "$file" ]; then
        log_error "ファイルが指定されていません"
        exit 1
    fi

    # 相対パスの場合はSHARED_DIRを基準に
    if [[ ! "$file" = /* ]]; then
        file="$SHARED_DIR/$file"
    fi

    if [ ! -f "$file" ]; then
        log_error "ファイルが存在しません: $file"
        exit 1
    fi

    cat "$file"
}

# ステータス更新
update_status() {
    local file="" new_status=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --file) file="$2"; shift 2 ;;
            --status) new_status="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [ -z "$file" ] || [ -z "$new_status" ]; then
        log_error "--file と --status が必要です"
        exit 1
    fi

    # 相対パスの場合
    if [[ ! "$file" = /* ]]; then
        file="$SHARED_DIR/$file"
    fi

    if [ ! -f "$file" ]; then
        log_error "ファイルが存在しません: $file"
        exit 1
    fi

    # ステータス更新
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    sed -i "s/^status: .*/status: $new_status/" "$file"
    sed -i "s/^updated_at: .*/updated_at: $timestamp/" "$file"

    log_success "ステータスを更新しました: $new_status"
}

# 新着監視
watch_messages() {
    local dir="" interval=5

    while [[ $# -gt 0 ]]; do
        case $1 in
            --dir) dir="$2"; shift 2 ;;
            --interval) interval="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [ -z "$dir" ]; then
        log_error "--dir が指定されていません"
        exit 1
    fi

    local target="$SHARED_DIR/$dir"
    local last_check="/tmp/.agent-corp-watch-$(echo "$target" | md5sum | cut -d' ' -f1)"

    log_info "監視開始: $target (間隔: ${interval}秒)"
    log_info "Ctrl+C で終了"
    echo ""

    # 初回チェックポイント
    touch "$last_check"

    while true; do
        # 新着ファイルの検出
        local new_files=$(find "$target" -name "*.md" -newer "$last_check" -type f 2>/dev/null)

        if [ -n "$new_files" ]; then
            echo "$new_files" | while read file; do
                local filename=$(basename "$file")
                local title=$(grep "^# " "$file" 2>/dev/null | head -1 | sed 's/^# //')
                log_success "新着: $filename - $title"
            done
        fi

        # チェックポイント更新
        touch "$last_check"

        sleep "$interval"
    done
}

# 全未処理タスクを処理済みにマーク（リセット）
reset_all() {
    local dry_run=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run) dry_run=true; shift ;;
            *) shift ;;
        esac
    done

    # PROJECT_DIRを特定（agent-loop.shと同じフルパスを使う必要がある）
    local project_dir
    project_dir="$(cd "$(dirname "$0")/.." && pwd)"
    local processed_dir="$project_dir/shared/.processed"
    local shared="$project_dir/shared"

    mkdir -p "$processed_dir"

    # 対象ディレクトリ一覧（agent-loop.shが監視する全ディレクトリ）
    local dirs=(
        "$shared/requirements"
        "$shared/instructions/pm"
        "$shared/tasks/frontend"
        "$shared/tasks/backend"
        "$shared/tasks/security"
        "$shared/tasks/qa"
        "$shared/reports/pm"
        "$shared/reports/engineers/frontend"
        "$shared/reports/engineers/backend"
        "$shared/reports/engineers/security"
        "$shared/reports/human"
        "$shared/reports/intern"
    )

    local total=0
    local skipped=0

    for dir in "${dirs[@]}"; do
        [ -d "$dir" ] || continue
        for file in "$dir"/*.md; do
            [ -f "$file" ] || continue
            local hash=$(echo "$file" | md5sum | cut -d' ' -f1)
            if [ -f "$processed_dir/$hash" ]; then
                skipped=$((skipped + 1))
                continue
            fi
            total=$((total + 1))
            if [ "$dry_run" = true ]; then
                echo "  $(basename "$file")  ← $(basename "$(dirname "$file")")"
            else
                touch "$processed_dir/$hash"
            fi
        done
    done

    if [ "$dry_run" = true ]; then
        echo ""
        log_info "リセット対象: ${total}件（既に処理済み: ${skipped}件）"
        log_info "実行するには: $0 reset"
    else
        if [ $total -eq 0 ]; then
            log_info "リセット対象のファイルはありません（全${skipped}件が処理済み）"
        else
            log_success "リセット完了: ${total}件を処理済みにマーク（スキップ: ${skipped}件）"
            log_info "新しい依頼を送信できます: $0 send ..."
        fi
    fi
}

# メイン処理
main() {
    local command=${1:-help}
    shift || true

    case $command in
        send)
            send_message "$@"
            ;;
        list)
            list_messages "$@"
            ;;
        read)
            read_message "$@"
            ;;
        status)
            update_status "$@"
            ;;
        watch)
            watch_messages "$@"
            ;;
        reset)
            reset_all "$@"
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
