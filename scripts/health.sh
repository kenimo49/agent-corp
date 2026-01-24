#!/bin/bash

# agent-corp ヘルスチェック・リカバリスクリプト
# システムの健全性を監視し、問題があれば自動復旧を試みる

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SHARED_DIR="$PROJECT_DIR/shared"
LOG_DIR="$SHARED_DIR/logs"

# 設定
STALE_THRESHOLD_HOURS=24   # この時間を超えてpendingのメッセージは警告
BLOCKED_ALERT_HOURS=1      # この時間を超えてblockedのメッセージはアラート

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
    check       ヘルスチェックを実行
    fix         検出された問題を修復
    watch       継続的にヘルスチェックを実行
    cleanup     古いファイルをクリーンアップ
    recover     ブロックされたタスクをリカバリ
    help        このヘルプを表示

Check Options:
    --verbose   詳細な出力

Watch Options:
    --interval <min>    チェック間隔（分） [default: 5]

Cleanup Options:
    --days <n>          n日より古いcompletedファイルをアーカイブ [default: 7]
    --dry-run           実際には削除せず、対象を表示

Examples:
    $0 check                    # ヘルスチェック
    $0 check --verbose          # 詳細なヘルスチェック
    $0 fix                      # 問題を修復
    $0 cleanup --days 14        # 14日より古いファイルをアーカイブ
    $0 watch --interval 10      # 10分間隔で監視

EOF
}

# タイムスタンプをログに記録
log_to_file() {
    local level="$1"
    local message="$2"
    local log_file="$LOG_DIR/$(date +%Y%m%d).log"

    mkdir -p "$LOG_DIR"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$log_file"
}

# ディレクトリ構造のチェック
check_directory_structure() {
    local issues=0

    log_info "ディレクトリ構造をチェック中..."

    local required_dirs=(
        "requirements"
        "instructions/pm"
        "tasks/frontend"
        "tasks/backend"
        "tasks/security"
        "reports/human"
        "reports/pm"
        "reports/engineers/frontend"
        "reports/engineers/backend"
        "reports/engineers/security"
        "questions/answers"
        "specs"
        "logs"
        "archive"
    )

    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$SHARED_DIR/$dir" ]; then
            log_warn "ディレクトリが見つかりません: $dir"
            issues=$((issues + 1))
        fi
    done

    if [ $issues -eq 0 ]; then
        log_success "ディレクトリ構造: OK"
    else
        log_error "ディレクトリ構造: $issues 件の問題"
    fi

    return $issues
}

# 古いpendingメッセージのチェック
check_stale_messages() {
    local issues=0
    local threshold_minutes=$((STALE_THRESHOLD_HOURS * 60))

    log_info "古いpendingメッセージをチェック中..."

    while IFS= read -r file; do
        if [ -n "$file" ] && [ -f "$file" ]; then
            local age_minutes=$(( ($(date +%s) - $(stat -c %Y "$file" 2>/dev/null || echo 0)) / 60 ))
            if [ $age_minutes -gt $threshold_minutes ]; then
                log_warn "古いpendingメッセージ: $(basename "$file") (${age_minutes}分前)"
                log_to_file "WARN" "Stale pending message: $file (${age_minutes} minutes old)"
                issues=$((issues + 1))
            fi
        fi
    done < <(find "$SHARED_DIR" -name "*.md" -type f -exec grep -l "status: pending" {} \; 2>/dev/null)

    if [ $issues -eq 0 ]; then
        log_success "古いpendingメッセージ: なし"
    else
        log_warn "古いpendingメッセージ: $issues 件"
    fi

    return $issues
}

# ブロックされたメッセージのチェック
check_blocked_messages() {
    local issues=0
    local threshold_minutes=$((BLOCKED_ALERT_HOURS * 60))

    log_info "ブロックされたメッセージをチェック中..."

    while IFS= read -r file; do
        if [ -n "$file" ] && [ -f "$file" ]; then
            local age_minutes=$(( ($(date +%s) - $(stat -c %Y "$file" 2>/dev/null || echo 0)) / 60 ))
            if [ $age_minutes -gt $threshold_minutes ]; then
                log_error "長時間ブロック中: $(basename "$file") (${age_minutes}分前)"
                log_to_file "ERROR" "Long-blocked message: $file (${age_minutes} minutes old)"
                issues=$((issues + 1))
            fi
        fi
    done < <(find "$SHARED_DIR" -name "*.md" -type f -exec grep -l "status: blocked" {} \; 2>/dev/null)

    if [ $issues -eq 0 ]; then
        log_success "ブロック中メッセージ: なし"
    else
        log_error "ブロック中メッセージ: $issues 件"
    fi

    return $issues
}

# メッセージ形式のチェック
check_message_format() {
    local issues=0

    log_info "メッセージ形式をチェック中..."

    local required_fields=("id:" "from:" "to:" "type:" "status:")

    while IFS= read -r file; do
        if [ -n "$file" ] && [ -f "$file" ]; then
            for field in "${required_fields[@]}"; do
                if ! grep -q "^$field" "$file" 2>/dev/null; then
                    log_warn "必須フィールドがありません: $field in $(basename "$file")"
                    issues=$((issues + 1))
                fi
            done
        fi
    done < <(find "$SHARED_DIR" -name "*.md" -type f 2>/dev/null | head -50)

    if [ $issues -eq 0 ]; then
        log_success "メッセージ形式: OK"
    else
        log_warn "メッセージ形式: $issues 件の問題"
    fi

    return $issues
}

# ディスク容量のチェック
check_disk_space() {
    log_info "ディスク容量をチェック中..."

    local usage=$(df -h "$SHARED_DIR" 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')

    if [ -z "$usage" ]; then
        log_warn "ディスク容量を取得できません"
        return 1
    fi

    if [ "$usage" -gt 90 ]; then
        log_error "ディスク容量が危険レベル: ${usage}%"
        log_to_file "ERROR" "Disk usage critical: ${usage}%"
        return 1
    elif [ "$usage" -gt 80 ]; then
        log_warn "ディスク容量が警告レベル: ${usage}%"
        log_to_file "WARN" "Disk usage warning: ${usage}%"
        return 0
    else
        log_success "ディスク容量: ${usage}%"
        return 0
    fi
}

# ヘルスチェック実行
run_health_check() {
    local verbose=false
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose) verbose=true; shift ;;
            *) shift ;;
        esac
    done

    echo "========================================"
    echo "  agent-corp ヘルスチェック"
    echo "  $(date '+%Y-%m-%d %H:%M:%S')"
    echo "========================================"
    echo ""

    local total_issues=0

    # ディレクトリ構造
    check_directory_structure || total_issues=$((total_issues + $?))
    echo ""

    # ディスク容量
    check_disk_space || total_issues=$((total_issues + $?))
    echo ""

    # 古いpendingメッセージ
    check_stale_messages || total_issues=$((total_issues + $?))
    echo ""

    # ブロックされたメッセージ
    check_blocked_messages || total_issues=$((total_issues + $?))
    echo ""

    # メッセージ形式
    if [ "$verbose" = true ]; then
        check_message_format || total_issues=$((total_issues + $?))
        echo ""
    fi

    # サマリー
    echo "========================================"
    if [ $total_issues -eq 0 ]; then
        log_success "ヘルスチェック完了: すべて正常"
        log_to_file "INFO" "Health check passed"
    else
        log_warn "ヘルスチェック完了: $total_issues 件の問題"
        log_to_file "WARN" "Health check found $total_issues issues"
    fi

    return $total_issues
}

# 問題の修復
fix_issues() {
    echo "========================================"
    echo "  agent-corp 問題修復"
    echo "========================================"
    echo ""

    # ディレクトリ構造の修復
    log_info "ディレクトリ構造を修復中..."
    "$SCRIPT_DIR/init-shared.sh" "$SHARED_DIR" > /dev/null
    log_success "ディレクトリ構造を修復しました"
    echo ""

    # 不正なステータスの修正
    log_info "不正なステータスをチェック中..."
    local fixed=0
    while IFS= read -r file; do
        if [ -n "$file" ] && [ -f "$file" ]; then
            # updated_atがない場合は追加
            if ! grep -q "^updated_at:" "$file" 2>/dev/null; then
                local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
                sed -i "/^status:/a updated_at: $timestamp" "$file"
                fixed=$((fixed + 1))
            fi
        fi
    done < <(find "$SHARED_DIR" -name "*.md" -type f 2>/dev/null)

    if [ $fixed -gt 0 ]; then
        log_success "$fixed 件のファイルを修正しました"
    else
        log_success "修正が必要なファイルはありません"
    fi

    log_to_file "INFO" "Fix completed"
}

# 古いファイルのクリーンアップ
cleanup_old_files() {
    local days=7
    local dry_run=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --days) days="$2"; shift 2 ;;
            --dry-run) dry_run=true; shift ;;
            *) shift ;;
        esac
    done

    echo "========================================"
    echo "  agent-corp クリーンアップ"
    echo "  対象: ${days}日より古いcompletedファイル"
    echo "========================================"
    echo ""

    local archive_dir="$SHARED_DIR/archive/$(date +%Y%m%d)"

    if [ "$dry_run" = false ]; then
        mkdir -p "$archive_dir"
    fi

    local count=0
    while IFS= read -r file; do
        if [ -n "$file" ] && [ -f "$file" ]; then
            if grep -q "status: completed" "$file" 2>/dev/null; then
                if [ "$dry_run" = true ]; then
                    log_info "[DRY-RUN] アーカイブ対象: $(basename "$file")"
                else
                    mv "$file" "$archive_dir/"
                    log_success "アーカイブ: $(basename "$file")"
                fi
                count=$((count + 1))
            fi
        fi
    done < <(find "$SHARED_DIR" -name "*.md" -type f -mtime +"$days" 2>/dev/null)

    echo ""
    if [ $count -eq 0 ]; then
        log_info "アーカイブ対象のファイルはありません"
    else
        if [ "$dry_run" = true ]; then
            log_info "[DRY-RUN] $count 件のファイルがアーカイブ対象です"
        else
            log_success "$count 件のファイルをアーカイブしました: $archive_dir"
            log_to_file "INFO" "Archived $count files to $archive_dir"
        fi
    fi
}

# ブロックされたタスクのリカバリ
recover_blocked() {
    echo "========================================"
    echo "  agent-corp ブロック解除"
    echo "========================================"
    echo ""

    local blocked_files=$(find "$SHARED_DIR" -name "*.md" -type f -exec grep -l "status: blocked" {} \; 2>/dev/null)

    if [ -z "$blocked_files" ]; then
        log_info "ブロック中のタスクはありません"
        return 0
    fi

    echo "$blocked_files" | while read file; do
        if [ -n "$file" ] && [ -f "$file" ]; then
            local filename=$(basename "$file")
            local title=$(grep "^# " "$file" 2>/dev/null | head -1 | sed 's/^# //')

            echo ""
            log_warn "ブロック中: $filename"
            echo "  タイトル: $title"

            read -p "  ステータスをpendingに戻しますか？ (y/n): " answer
            if [ "$answer" = "y" ]; then
                local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
                sed -i "s/^status: blocked/status: pending/" "$file"
                sed -i "s/^updated_at: .*/updated_at: $timestamp/" "$file"
                log_success "ステータスをpendingに変更しました"
                log_to_file "INFO" "Recovered blocked task: $file"
            fi
        fi
    done
}

# 継続的監視
watch_health() {
    local interval=5

    while [[ $# -gt 0 ]]; do
        case $1 in
            --interval) interval="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    log_info "ヘルスチェック監視を開始します（間隔: ${interval}分）"
    log_info "Ctrl+C で終了"
    echo ""

    while true; do
        run_health_check
        echo ""
        log_info "次のチェック: ${interval}分後"
        sleep $((interval * 60))
        clear
    done
}

# メイン処理
main() {
    local command=${1:-help}
    shift || true

    case $command in
        check)
            run_health_check "$@"
            ;;
        fix)
            fix_issues
            ;;
        watch)
            watch_health "$@"
            ;;
        cleanup)
            cleanup_old_files "$@"
            ;;
        recover)
            recover_blocked
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
