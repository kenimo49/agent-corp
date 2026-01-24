#!/bin/bash

# agent-corp E2Eテストスクリプト
# 基本的な通信フローの動作を検証する

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SHARED_DIR="$PROJECT_DIR/shared"

# 色付きログ
log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[PASS]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[FAIL]\033[0m $1"; }
log_warn() { echo -e "\033[0;33m[WARN]\033[0m $1"; }
log_test() { echo -e "\033[0;35m[TEST]\033[0m $1"; }

# テスト結果カウンター
PASSED=0
FAILED=0

# アサーション関数
assert_file_exists() {
    local file="$1"
    local msg="$2"
    if [ -f "$file" ]; then
        log_success "$msg"
        PASSED=$((PASSED + 1))
    else
        log_error "$msg (ファイルが見つかりません: $file)"
        FAILED=$((FAILED + 1))
    fi
}

assert_dir_has_files() {
    local dir="$1"
    local expected="$2"
    local msg="$3"
    local count=$(find "$dir" -name "*.md" -type f 2>/dev/null | wc -l)
    if [ "$count" -ge "$expected" ]; then
        log_success "$msg (found: $count)"
        PASSED=$((PASSED + 1))
    else
        log_error "$msg (expected: $expected, found: $count)"
        FAILED=$((FAILED + 1))
    fi
}

assert_command_success() {
    local cmd="$1"
    local msg="$2"
    if eval "$cmd" > /dev/null 2>&1; then
        log_success "$msg"
        PASSED=$((PASSED + 1))
    else
        log_error "$msg (コマンド失敗: $cmd)"
        FAILED=$((FAILED + 1))
    fi
}

assert_output_contains() {
    local cmd="$1"
    local expected="$2"
    local msg="$3"
    local output=$(eval "$cmd" 2>&1)
    if echo "$output" | grep -q "$expected"; then
        log_success "$msg"
        PASSED=$((PASSED + 1))
    else
        log_error "$msg (期待値 '$expected' が見つかりません)"
        FAILED=$((FAILED + 1))
    fi
}

# クリーンアップ
cleanup() {
    log_info "テスト環境をクリーンアップ中..."
    rm -rf "$SHARED_DIR"
    rm -rf "$PROJECT_DIR/src"
    "$SCRIPT_DIR/init-shared.sh" "$SHARED_DIR" > /dev/null
    mkdir -p "$PROJECT_DIR/src"
}

# テスト: メッセージ送信
test_message_send() {
    log_test "=== テスト: メッセージ送信 ==="

    # 要件の送信
    "$SCRIPT_DIR/msg.sh" send \
        --from human \
        --to ceo \
        --type requirement \
        --priority medium \
        --title "Hello Worldプログラムの作成" \
        --body "シンプルなHello Worldプログラムを作成してください。"

    assert_dir_has_files "$SHARED_DIR/requirements" 1 "要件ファイルが作成される"
}

# テスト: メッセージ一覧
test_message_list() {
    log_test "=== テスト: メッセージ一覧 ==="

    local output=$("$SCRIPT_DIR/msg.sh" list --dir requirements 2>&1)

    if echo "$output" | grep -q "Hello World"; then
        log_success "一覧にメッセージが表示される"
        PASSED=$((PASSED + 1))
    else
        log_error "一覧にメッセージが表示されない"
        FAILED=$((FAILED + 1))
    fi
}

# テスト: ステータス更新
test_status_update() {
    log_test "=== テスト: ステータス更新 ==="

    local file=$(find "$SHARED_DIR/requirements" -name "*.md" -type f | head -1)
    if [ -n "$file" ]; then
        "$SCRIPT_DIR/msg.sh" status --file "$file" --status in_progress

        if grep -q "status: in_progress" "$file"; then
            log_success "ステータスが更新される"
            PASSED=$((PASSED + 1))
        else
            log_error "ステータスが更新されない"
            FAILED=$((FAILED + 1))
        fi
    else
        log_error "テスト対象ファイルがない"
        FAILED=$((FAILED + 1))
    fi
}

# テスト: 全フロー（Human → CEO → PM → Backend → PM → CEO → Human）
test_full_flow() {
    log_test "=== テスト: 全フロー（E2E） ==="

    # Step 1: Human → CEO
    "$SCRIPT_DIR/msg.sh" send \
        --from human --to ceo --type requirement --priority high \
        --title "E2Eテストタスク" --body "テスト用のタスクです"

    # Step 2: CEO → PM
    "$SCRIPT_DIR/msg.sh" send \
        --from ceo --to pm --type instruction --priority high \
        --title "E2Eテスト指示" --body "Backend Engineerにタスクを割り当ててください"

    # Step 3: PM → Backend
    "$SCRIPT_DIR/msg.sh" send \
        --from pm --to backend --type task --priority high \
        --title "E2Eテストタスク実装" --body "テスト用のプログラムを実装してください"

    # Step 4: Backend → PM (報告)
    "$SCRIPT_DIR/msg.sh" send \
        --from backend --to pm --type report --priority medium \
        --title "E2Eテストタスク完了" --body "実装が完了しました"

    # Step 5: PM → CEO (報告)
    "$SCRIPT_DIR/msg.sh" send \
        --from pm --to ceo --type report --priority medium \
        --title "E2Eテスト進捗報告" --body "タスクが完了しました"

    # Step 6: CEO → Human (報告)
    "$SCRIPT_DIR/msg.sh" send \
        --from ceo --to human --type report --priority medium \
        --title "E2Eテスト完了報告" --body "すべてのタスクが完了しました"

    # 検証
    assert_dir_has_files "$SHARED_DIR/requirements" 2 "要件ファイル"
    assert_dir_has_files "$SHARED_DIR/instructions/pm" 1 "指示ファイル"
    assert_dir_has_files "$SHARED_DIR/tasks/backend" 1 "タスクファイル"
    assert_dir_has_files "$SHARED_DIR/reports/engineers/backend" 1 "Backend報告ファイル"
    assert_dir_has_files "$SHARED_DIR/reports/pm" 1 "PM報告ファイル"
    assert_dir_has_files "$SHARED_DIR/reports/human" 1 "CEO報告ファイル"
}

# テスト: 質問・回答フロー
test_qa_flow() {
    log_test "=== テスト: 質問・回答フロー ==="

    # 質問
    "$SCRIPT_DIR/msg.sh" send \
        --from backend --to frontend --type question --priority high \
        --title "API形式について" --body "JSONの形式はどうしますか？"

    # 回答
    "$SCRIPT_DIR/msg.sh" send \
        --from frontend --to backend --type answer --priority high \
        --title "API形式について" --body "ネストされた形式を推奨します"

    assert_dir_has_files "$SHARED_DIR/questions/backend-to-frontend" 1 "質問ファイル"
    assert_dir_has_files "$SHARED_DIR/questions/answers" 1 "回答ファイル"
}

# テスト: エラーケース
test_error_cases() {
    log_test "=== テスト: エラーケース ==="

    # 必須パラメータ不足
    if "$SCRIPT_DIR/msg.sh" send --from human 2>&1 | grep -q "必須パラメータ"; then
        log_success "必須パラメータ不足でエラー"
        PASSED=$((PASSED + 1))
    else
        log_error "必須パラメータ不足のエラーが出ない"
        FAILED=$((FAILED + 1))
    fi

    # 存在しないディレクトリ
    if "$SCRIPT_DIR/msg.sh" list --dir nonexistent 2>&1 | grep -q "存在しません"; then
        log_success "存在しないディレクトリでエラー"
        PASSED=$((PASSED + 1))
    else
        log_error "存在しないディレクトリのエラーが出ない"
        FAILED=$((FAILED + 1))
    fi
}

# メイン処理
main() {
    echo ""
    echo "========================================"
    echo "  agent-corp E2E テスト"
    echo "========================================"
    echo ""

    # クリーンアップ
    cleanup

    # テスト実行
    test_message_send
    echo ""
    test_message_list
    echo ""
    test_status_update
    echo ""
    test_full_flow
    echo ""
    test_qa_flow
    echo ""
    test_error_cases

    # 結果サマリー
    echo ""
    echo "========================================"
    echo "  テスト結果"
    echo "========================================"
    echo ""
    echo "  PASSED: $PASSED"
    echo "  FAILED: $FAILED"
    echo ""

    if [ $FAILED -eq 0 ]; then
        log_success "すべてのテストが成功しました"
        exit 0
    else
        log_error "$FAILED 件のテストが失敗しました"
        exit 1
    fi
}

main "$@"
