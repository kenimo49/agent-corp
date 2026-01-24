#!/bin/bash

# agent-corp tmux 起動スクリプト
# 複数のAIエージェントをtmuxセッション内で起動・管理する

set -e

# 設定
SESSION_NAME="agent-corp"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# 色付きログ
log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[OK]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; }

# 使用方法
usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Commands:
    start       セッションを作成し、エージェントを起動 (デフォルト)
    stop        セッションを終了
    attach      既存のセッションにアタッチ
    status      セッションの状態を表示
    help        このヘルプを表示

Options:
    --llm <type>    使用するLLMエージェント (claude|aider|gpt) [default: claude]
    --dry-run       実行せずにコマンドを表示

Examples:
    $0 start                    # Claude Codeでセッション開始
    $0 start --llm aider        # Aiderでセッション開始
    $0 attach                   # 既存セッションにアタッチ
    $0 stop                     # セッション終了

EOF
}

# tmuxがインストールされているか確認
check_tmux() {
    if ! command -v tmux &> /dev/null; then
        log_error "tmux がインストールされていません"
        echo "インストール方法:"
        echo "  Ubuntu/Debian: sudo apt install tmux"
        echo "  macOS: brew install tmux"
        exit 1
    fi
}

# セッションの存在確認
session_exists() {
    tmux has-session -t "$SESSION_NAME" 2>/dev/null
}

# 共有ディレクトリの初期化
init_shared_dirs() {
    log_info "共有ディレクトリを初期化中..."

    mkdir -p "$PROJECT_DIR/shared"/{requirements,instructions/pm,tasks/{frontend,backend,security},reports/{human,pm,engineers/{frontend,backend,security}},specs/api}

    log_success "共有ディレクトリを作成しました"
}

# LLMエージェント起動コマンドの生成
get_agent_command() {
    local role=$1
    local llm_type=$2
    local prompt_file="$PROJECT_DIR/prompts/$role.md"

    case $llm_type in
        claude)
            # Claude Code を使用
            echo "cd $PROJECT_DIR && claude --system-prompt '$prompt_file'"
            ;;
        aider)
            # Aider を使用
            echo "cd $PROJECT_DIR && aider --read '$prompt_file'"
            ;;
        gpt)
            # GPT CLI を使用（仮）
            echo "cd $PROJECT_DIR && echo '[TODO] GPT CLI for $role - Prompt: $prompt_file' && bash"
            ;;
        *)
            echo "cd $PROJECT_DIR && echo 'Agent: $role' && bash"
            ;;
    esac
}

# セッション開始
start_session() {
    local llm_type=${1:-claude}
    local dry_run=${2:-false}

    if session_exists; then
        log_error "セッション '$SESSION_NAME' は既に存在します"
        echo "アタッチするには: $0 attach"
        echo "終了するには: $0 stop"
        exit 1
    fi

    log_info "セッション '$SESSION_NAME' を作成中..."

    # 共有ディレクトリの初期化
    init_shared_dirs

    # tmuxセッション作成（最初のウィンドウ: CEO）
    local cmd_ceo=$(get_agent_command "ceo" "$llm_type")

    if [ "$dry_run" = true ]; then
        echo "[DRY-RUN] tmux new-session -d -s $SESSION_NAME -n ceo"
        echo "[DRY-RUN] CEO command: $cmd_ceo"
    else
        tmux new-session -d -s "$SESSION_NAME" -n "ceo"
        tmux send-keys -t "$SESSION_NAME:ceo" "clear && echo '=== CEO AI ===' && echo 'Prompt: prompts/ceo.md'" Enter
    fi

    # PM ウィンドウ作成
    local cmd_pm=$(get_agent_command "pm" "$llm_type")
    if [ "$dry_run" = true ]; then
        echo "[DRY-RUN] tmux new-window -t $SESSION_NAME -n pm"
        echo "[DRY-RUN] PM command: $cmd_pm"
    else
        tmux new-window -t "$SESSION_NAME" -n "pm"
        tmux send-keys -t "$SESSION_NAME:pm" "clear && echo '=== PM AI ===' && echo 'Prompt: prompts/pm.md'" Enter
    fi

    # Engineer ウィンドウ作成（3ペイン分割）
    if [ "$dry_run" = true ]; then
        echo "[DRY-RUN] tmux new-window -t $SESSION_NAME -n engineers"
        echo "[DRY-RUN] Frontend command: $(get_agent_command "engineers/frontend" "$llm_type")"
        echo "[DRY-RUN] Backend command: $(get_agent_command "engineers/backend" "$llm_type")"
        echo "[DRY-RUN] Security command: $(get_agent_command "engineers/security" "$llm_type")"
    else
        tmux new-window -t "$SESSION_NAME" -n "engineers"

        # 3分割レイアウト
        tmux split-window -h -t "$SESSION_NAME:engineers"
        tmux split-window -v -t "$SESSION_NAME:engineers.1"

        # 各ペインにエージェント情報を表示
        tmux send-keys -t "$SESSION_NAME:engineers.0" "clear && echo '=== Frontend Engineer AI ===' && echo 'Prompt: prompts/engineers/frontend.md'" Enter
        tmux send-keys -t "$SESSION_NAME:engineers.1" "clear && echo '=== Backend Engineer AI ===' && echo 'Prompt: prompts/engineers/backend.md'" Enter
        tmux send-keys -t "$SESSION_NAME:engineers.2" "clear && echo '=== Security Engineer AI ===' && echo 'Prompt: prompts/engineers/security.md'" Enter

        # レイアウト調整
        tmux select-layout -t "$SESSION_NAME:engineers" main-vertical
    fi

    # 監視用ウィンドウ
    if [ "$dry_run" = true ]; then
        echo "[DRY-RUN] tmux new-window -t $SESSION_NAME -n monitor"
    else
        tmux new-window -t "$SESSION_NAME" -n "monitor"
        tmux send-keys -t "$SESSION_NAME:monitor" "cd $PROJECT_DIR && watch -n 2 'echo \"=== Shared Directory ===\"; ls -la shared/'" Enter
    fi

    # CEOウィンドウを選択
    if [ "$dry_run" != true ]; then
        tmux select-window -t "$SESSION_NAME:ceo"
    fi

    log_success "セッション '$SESSION_NAME' を作成しました"
    echo ""
    echo "ウィンドウ構成:"
    echo "  0: ceo       - CEO AI"
    echo "  1: pm        - PM AI"
    echo "  2: engineers - Frontend / Backend / Security"
    echo "  3: monitor   - 共有ディレクトリ監視"
    echo ""
    echo "アタッチするには: tmux attach -t $SESSION_NAME"
    echo "または: $0 attach"
}

# セッション終了
stop_session() {
    if ! session_exists; then
        log_error "セッション '$SESSION_NAME' は存在しません"
        exit 1
    fi

    log_info "セッション '$SESSION_NAME' を終了中..."
    tmux kill-session -t "$SESSION_NAME"
    log_success "セッションを終了しました"
}

# セッションにアタッチ
attach_session() {
    if ! session_exists; then
        log_error "セッション '$SESSION_NAME' は存在しません"
        echo "開始するには: $0 start"
        exit 1
    fi

    tmux attach -t "$SESSION_NAME"
}

# ステータス表示
show_status() {
    if session_exists; then
        log_success "セッション '$SESSION_NAME' は実行中です"
        echo ""
        tmux list-windows -t "$SESSION_NAME"
    else
        log_info "セッション '$SESSION_NAME' は存在しません"
    fi
}

# メイン処理
main() {
    local command=${1:-start}
    local llm_type="claude"
    local dry_run=false

    # 引数解析
    shift || true
    while [[ $# -gt 0 ]]; do
        case $1 in
            --llm)
                llm_type="$2"
                shift 2
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

    check_tmux

    case $command in
        start)
            start_session "$llm_type" "$dry_run"
            ;;
        stop)
            stop_session
            ;;
        attach)
            attach_session
            ;;
        status)
            show_status
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
