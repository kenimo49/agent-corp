#!/bin/bash

# agent-corp tmux 起動スクリプト
# 複数のAIエージェントをtmuxセッション内で起動・管理する

set -e

# 設定
SESSION_NAME="agent-corp"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# RAG・ターゲットプロジェクト設定の読み込み
source "$PROJECT_DIR/scripts/config.sh"

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
    --llm <type>    使用するLLMエージェント [default: claude-loop]
                    claude      - Claude Code対話モード
                    claude-loop - claude -p ループモード（自動監視）★推奨
                    codex       - OpenAI Codex対話モード
                    codex-loop  - Codex ループモード（自動監視）
                    # gemini      - Gemini CLI対話モード（現在無効）
                    # gemini-loop - Gemini ループモード（現在無効）
                    aider       - Aider
                    gpt         - GPT CLI（未実装）
                    none        - LLMなし（シェルのみ）
    --dry-run       実行せずにコマンドを表示

Examples:
    $0 start                        # claude-loopでセッション開始（自動監視）
    $0 start --llm claude           # Claude Code対話モードでセッション開始
    $0 start --llm none             # LLMなし（シェルのみ）でセッション開始
    $0 attach                       # 既存セッションにアタッチ
    $0 stop                         # セッション終了

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

    mkdir -p "$PROJECT_DIR/shared"/{requirements,instructions/pm,tasks/{frontend,backend,security,intern},reports/{human,pm,intern,engineers/{frontend,backend,security}},specs/api}

    log_success "共有ディレクトリを作成しました"
}

# 各エージェントに初期プロンプトを送信
send_initial_prompts() {
    local llm_type=$1

    # loopモードやnoneモードでは初期プロンプト不要（自動監視）
    case "$llm_type" in
        none|claude-loop|codex-loop)
            # gemini-loop は現在無効
            return
            ;;
    esac

    log_info "エージェントの起動を待機中（15秒）..."
    sleep 15

    log_info "初期プロンプトを送信中..."

    # CEO: 要件ディレクトリを監視して処理開始
    tmux send-keys -t "$SESSION_NAME:ceo" "shared/requirements/ ディレクトリを確認してください。新しい要件ファイルがあれば、その内容を分析し、PMへの指示を shared/instructions/pm/ に作成してください。" Enter

    # PM: 指示ディレクトリを監視
    tmux send-keys -t "$SESSION_NAME:pm" "shared/instructions/pm/ ディレクトリを確認してください。CEOからの指示があれば、タスクに分解して各エンジニアの shared/tasks/ に割り当ててください。" Enter

    # Engineers: タスクディレクトリを監視
    tmux send-keys -t "$SESSION_NAME:engineers.0" "shared/tasks/frontend/ ディレクトリを確認してください。新しいタスクがあれば実装を開始してください。" Enter
    tmux send-keys -t "$SESSION_NAME:engineers.1" "shared/tasks/backend/ ディレクトリを確認してください。新しいタスクがあれば実装を開始してください。" Enter
    tmux send-keys -t "$SESSION_NAME:engineers.2" "shared/tasks/security/ ディレクトリを確認してください。新しいタスクがあれば実装を開始してください。" Enter

    log_success "初期プロンプトを送信しました"
}

# LLMエージェント起動コマンドの生成
get_agent_command() {
    local role=$1
    local llm_type=$2
    local prompt_file="$PROJECT_DIR/prompts/$role.md"

    # roleからagent-loop用のロール名を取得
    local loop_role=""
    case $role in
        ceo) loop_role="ceo" ;;
        pm) loop_role="pm" ;;
        intern) loop_role="intern" ;;
        engineers/frontend) loop_role="frontend" ;;
        engineers/backend) loop_role="backend" ;;
        engineers/security) loop_role="security" ;;
    esac

    case $llm_type in
        claude)
            # Claude Code を使用（システムプロンプトを設定して対話モードで起動）
            echo "cd $PROJECT_DIR && claude --system-prompt \"\$(cat '$prompt_file')\" --add-dir \"$TARGET_PROJECT\" --allowedTools \"Bash,Edit,Read,Write\" --dangerously-skip-permissions"
            ;;
        claude-loop)
            # claude -p をループで使用（自動監視モード）
            echo "cd $PROJECT_DIR && ./scripts/agent-loop.sh $loop_role"
            ;;
        codex)
            # OpenAI Codex CLI を使用（対話モード）
            echo "cd $TARGET_PROJECT && codex"
            ;;
        codex-loop)
            # codex -p をループで使用（自動監視モード）
            echo "cd $PROJECT_DIR && ./scripts/agent-loop.sh $loop_role codex"
            ;;
        # gemini)
        #     # Gemini CLI を使用（対話モード）- 現在無効
        #     echo "cd $PROJECT_DIR && gemini --system-instruction \"\$(cat '$prompt_file')\""
        #     ;;
        # gemini-loop)
        #     # gemini -p をループで使用（自動監視モード）- 現在無効
        #     echo "cd $PROJECT_DIR && ./scripts/agent-loop.sh $loop_role gemini"
        #     ;;
        aider)
            # Aider を使用
            echo "cd $PROJECT_DIR && aider --read '$prompt_file'"
            ;;
        gpt)
            # GPT CLI を使用（仮）
            echo "cd $PROJECT_DIR && echo '[TODO] GPT CLI for $role - Prompt: $prompt_file' && bash"
            ;;
        none)
            # LLMを起動せず、シェルのみ
            echo "cd $PROJECT_DIR && echo '=== $role ===' && echo 'Prompt: $prompt_file' && bash"
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
        tmux send-keys -t "$SESSION_NAME:ceo" "clear && echo '=== CEO AI ===' && $cmd_ceo" Enter
    fi

    # PM ウィンドウ作成
    local cmd_pm=$(get_agent_command "pm" "$llm_type")
    if [ "$dry_run" = true ]; then
        echo "[DRY-RUN] tmux new-window -t $SESSION_NAME -n pm"
        echo "[DRY-RUN] PM command: $cmd_pm"
    else
        tmux new-window -t "$SESSION_NAME" -n "pm"
        tmux send-keys -t "$SESSION_NAME:pm" "clear && echo '=== PM AI ===' && $cmd_pm" Enter
    fi

    # Intern ウィンドウ作成（Codex使用）
    local cmd_intern=$(get_agent_command "intern" "codex-loop")
    if [ "$dry_run" = true ]; then
        echo "[DRY-RUN] tmux new-window -t $SESSION_NAME -n intern"
        echo "[DRY-RUN] Intern command: $cmd_intern (Codex)"
    else
        tmux new-window -t "$SESSION_NAME" -n "intern"
        tmux send-keys -t "$SESSION_NAME:intern" "clear && echo '=== Intern AI (Codex) ===' && $cmd_intern" Enter
    fi

    # Engineer ウィンドウ作成（3ペイン分割）
    local cmd_frontend=$(get_agent_command "engineers/frontend" "$llm_type")
    local cmd_backend=$(get_agent_command "engineers/backend" "$llm_type")
    local cmd_security=$(get_agent_command "engineers/security" "$llm_type")

    if [ "$dry_run" = true ]; then
        echo "[DRY-RUN] tmux new-window -t $SESSION_NAME -n engineers"
        echo "[DRY-RUN] Frontend command: $cmd_frontend"
        echo "[DRY-RUN] Backend command: $cmd_backend"
        echo "[DRY-RUN] Security command: $cmd_security"
    else
        tmux new-window -t "$SESSION_NAME" -n "engineers"

        # 3分割レイアウト
        tmux split-window -h -t "$SESSION_NAME:engineers"
        tmux split-window -v -t "$SESSION_NAME:engineers.1"

        # 各ペインでLLMエージェントを起動
        tmux send-keys -t "$SESSION_NAME:engineers.0" "clear && echo '=== Frontend Engineer AI ===' && $cmd_frontend" Enter
        tmux send-keys -t "$SESSION_NAME:engineers.1" "clear && echo '=== Backend Engineer AI ===' && $cmd_backend" Enter
        tmux send-keys -t "$SESSION_NAME:engineers.2" "clear && echo '=== Security Engineer AI ===' && $cmd_security" Enter

        # レイアウト調整（均等分割）
        tmux select-layout -t "$SESSION_NAME:engineers" even-horizontal
    fi

    # 監視用ウィンドウ
    if [ "$dry_run" = true ]; then
        echo "[DRY-RUN] tmux new-window -t $SESSION_NAME -n monitor"
    else
        tmux new-window -t "$SESSION_NAME" -n "monitor"
        tmux send-keys -t "$SESSION_NAME:monitor" "cd $PROJECT_DIR && watch -n 2 'echo \"=== Shared Directory ===\"; ls -la shared/'" Enter
    fi

    # 6分割オーバービューウィンドウ（CEO/PM/Intern + Engineers）
    if [ "$dry_run" = true ]; then
        echo "[DRY-RUN] tmux new-window -t $SESSION_NAME -n overview"
        echo "[DRY-RUN] 6分割レイアウトで各エージェントを監視表示"
    else
        tmux new-window -t "$SESSION_NAME" -n "overview"

        # 6分割レイアウトを作成（2行3列）
        tmux split-window -h -t "$SESSION_NAME:overview"
        tmux split-window -h -t "$SESSION_NAME:overview.0"
        tmux split-window -v -t "$SESSION_NAME:overview.0"
        tmux split-window -v -t "$SESSION_NAME:overview.2"
        tmux split-window -v -t "$SESSION_NAME:overview.4"

        # 均等レイアウトに調整
        tmux select-layout -t "$SESSION_NAME:overview" tiled

        # 各ペインで対応するエージェントの画面をリアルタイム監視
        # Note: -J で折り返し行を結合、grep '.' で空行除去してからtail
        tmux send-keys -t "$SESSION_NAME:overview.0" "watch -n 1 'echo \"=== CEO ===\"; tmux capture-pane -t $SESSION_NAME:ceo.0 -p -J | grep \".\" | tail -12'" Enter
        tmux send-keys -t "$SESSION_NAME:overview.1" "watch -n 1 'echo \"=== PM ===\"; tmux capture-pane -t $SESSION_NAME:pm.0 -p -J | grep \".\" | tail -12'" Enter
        tmux send-keys -t "$SESSION_NAME:overview.2" "watch -n 1 'echo \"=== Intern (Codex) ===\"; tmux capture-pane -t $SESSION_NAME:intern.0 -p -J | grep \".\" | tail -12'" Enter
        tmux send-keys -t "$SESSION_NAME:overview.3" "watch -n 1 'echo \"=== Frontend ===\"; tmux capture-pane -t $SESSION_NAME:engineers.0 -p -J | grep \".\" | tail -12'" Enter
        tmux send-keys -t "$SESSION_NAME:overview.4" "watch -n 1 'echo \"=== Backend ===\"; tmux capture-pane -t $SESSION_NAME:engineers.1 -p -J | grep \".\" | tail -12'" Enter
        tmux send-keys -t "$SESSION_NAME:overview.5" "watch -n 1 'echo \"=== Security ===\"; tmux capture-pane -t $SESSION_NAME:engineers.2 -p -J | grep \".\" | tail -12'" Enter
    fi

    # CEOウィンドウを選択
    if [ "$dry_run" != true ]; then
        tmux select-window -t "$SESSION_NAME:ceo"
    fi

    log_success "セッション '$SESSION_NAME' を作成しました"
    log_info "ターゲットプロジェクト: $TARGET_PROJECT"

    # 初期プロンプトを送信（LLMが起動するまで待機してから）
    if [ "$dry_run" != true ]; then
        send_initial_prompts "$llm_type"
    fi
    echo ""
    echo "ウィンドウ構成:"
    echo "  0: ceo       - CEO AI"
    echo "  1: pm        - PM AI"
    echo "  2: intern    - Intern AI (Codex)"
    echo "  3: engineers - Frontend / Backend / Security"
    echo "  4: monitor   - 共有ディレクトリ監視"
    echo "  5: overview  - 6分割オーバービュー（Ctrl+b 5 で表示）"
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
    local llm_type="claude-loop"
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
