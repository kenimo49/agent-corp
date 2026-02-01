#!/bin/bash
# dashboard.sh - エージェント状態サマリーダッシュボード
# tmuxウィンドウ内で watch -n 5 ./scripts/dashboard.sh として使用

SESSION_NAME="${1:-agent-corp}"

# 色定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

# プロジェクトディレクトリ
PROJECT_DIR=$(tmux show-environment -t "$SESSION_NAME" PROJECT_DIR 2>/dev/null | cut -d= -f2)
if [ -z "$PROJECT_DIR" ]; then
    PROJECT_DIR="/home/ken/workspace/agent-corp"
fi
SHARED="$PROJECT_DIR/shared"

# タスクファイルからタイトル(Description)を取得
get_task_title() {
    local filename="$1"
    local file=""

    for dir in "$SHARED"/tasks/*/ "$SHARED"/instructions/pm/ "$SHARED"/reports/*/; do
        if [ -f "${dir}${filename}" ]; then
            file="${dir}${filename}"
            break
        fi
    done

    if [ -z "$file" ]; then
        file=$(find "$SHARED" -name "$filename" -type f 2>/dev/null | head -1)
    fi

    if [ -n "$file" ] && [ -f "$file" ]; then
        local title
        title=$(grep -m1 -oP '(Description|Title|タイトル):\s*\K.*' "$file" 2>/dev/null | sed 's/^[[:space:]|]*$//')
        if [ -n "$title" ] && [ ${#title} -gt 2 ]; then
            echo "$title"
            return
        fi
    fi
    echo ""
}

# ファイル名を短い概要に変換
humanize_filename() {
    local name="$1"
    echo "$name" | sed 's/\.md$//' \
        | sed 's/^[0-9]\{8\}-[0-9]*-//' \
        | sed 's/^T-//' \
        | sed 's/^inst-//' | sed 's/^req-//' \
        | sed 's/-task$//' | sed 's/-report$//' | sed 's/-instruction$//' \
        | sed 's/-pm-report$//' | sed 's/-report-final$//' \
        | tr '-' ' '
}

# タスクファイル名からestimate JSONの予測時間（分）を取得
get_estimate_minutes() {
    local task_file="$1"
    if [ -z "$task_file" ]; then
        echo ""
        return
    fi
    local base
    base=$(echo "$task_file" | sed 's/\.md$//')
    for est_file in "$SHARED"/.estimates/*/"${base}-estimate.json"; do
        if [ -f "$est_file" ]; then
            local mins
            mins=$(jq -r '.estimated_duration_minutes // empty' "$est_file" 2>/dev/null)
            if [ -n "$mins" ]; then
                echo "$mins"
                return
            fi
        fi
    done
    echo ""
}

# HH:MM:SS から経過時間を計算
elapsed_from() {
    local ts="$1"
    if [ -z "$ts" ]; then
        echo ""
        return
    fi
    local now_s=$(date +%s)
    local ts_s=$(date -d "$ts" +%s 2>/dev/null)
    if [ -z "$ts_s" ]; then
        echo ""
        return
    fi
    local diff=$(( now_s - ts_s ))
    if [ "$diff" -lt 0 ]; then diff=0; fi

    if [ "$diff" -lt 60 ]; then
        echo "${diff}s"
    elif [ "$diff" -lt 3600 ]; then
        echo "$(( diff / 60 ))m$(( diff % 60 ))s"
    else
        echo "$(( diff / 3600 ))h$(( diff % 3600 / 60 ))m"
    fi
}

# ペインから状態を取得（ステータス、ラベル、詳細、開始時刻、最終更新時刻）
get_status() {
    local target="$1"
    local lines
    lines=$(tmux capture-pane -t "$target" -p -J 2>/dev/null | grep '.' | tail -30)

    if [ -z "$lines" ]; then
        echo "IDLE|−|待機中|||"
        return
    fi

    local last_line
    last_line=$(echo "$lines" | tail -1)

    # タイムスタンプ抽出: "HH:MM:SS [INFO]..." 形式
    # 最終更新 = 最後の行のタイムスタンプ
    local last_ts
    last_ts=$(echo "$last_line" | grep -oP '^\d{2}:\d{2}:\d{2}' | head -1)

    if echo "$last_line" | grep -q '\[INFO\].*API.*処理中\|処理中$'; then
        # 処理中 → タスク検出行を探す
        local task_line
        task_line=$(echo "$lines" | grep '新しいタスクを検出\|新しい指示を検出\|新しい要件を検出\|報告を受信' | tail -1)
        local start_ts
        start_ts=$(echo "$task_line" | grep -oP '^\d{2}:\d{2}:\d{2}' | head -1)
        local task_file
        task_file=$(echo "$task_line" | grep -oP '(検出|受信): \K.*')

        # タイムスタンプがログに無い場合、タスクファイルの更新時刻をフォールバック
        if [ -z "$start_ts" ] && [ -n "$task_file" ]; then
            local found_file
            found_file=$(find "$SHARED" -name "$task_file" -type f 2>/dev/null | head -1)
            if [ -n "$found_file" ]; then
                start_ts=$(date -r "$found_file" '+%H:%M:%S' 2>/dev/null)
            fi
        fi

        local detail=""
        if [ -n "$task_file" ]; then
            detail=$(get_task_title "$task_file")
            if [ -z "$detail" ]; then
                detail=$(humanize_filename "$task_file")
                if [ ${#detail} -lt 6 ]; then
                    detail=$(echo "$task_file" | sed 's/\.md$//')
                fi
            fi
        elif echo "$last_line" | grep -q '最終報告を作成中'; then
            detail="最終報告を作成中"
        else
            detail="タスク実行中"
        fi

        echo "BUSY|処理中|$detail|$start_ts|$last_ts|$task_file"

    elif echo "$last_line" | grep -q '\[OK\]'; then
        local detail
        detail=$(echo "$last_line" | sed 's/.*\[OK\] //')
        if echo "$detail" | grep -q 'レポート作成\|報告を作成\|指示を作成\|タスク作成'; then
            local filename
            filename=$(echo "$detail" | grep -oP '[^/]+$')
            echo "DONE|完了|$(humanize_filename "$filename")||$last_ts|"
        else
            echo "DONE|完了|$detail||$last_ts|"
        fi

    elif echo "$last_line" | grep -q '\[ERROR\]'; then
        local detail
        detail=$(echo "$last_line" | sed 's/.*\[ERROR\] //')
        echo "ERROR|エラー|$detail||$last_ts|"

    elif echo "$last_line" | grep -q '監視:'; then
        echo "WATCH|待機|新しいタスクを待っています||$last_ts|"

    elif echo "$last_line" | grep -q '人間への報告完了'; then
        echo "WATCH|待機|新しいタスクを待っています||$last_ts|"

    elif echo "$last_line" | grep -qP '^\S+@\S+[:~]|^\$\s*$'; then
        # シェルプロンプトが最終行 → プロセスが停止している
        # 直前のログから最後のタイムスタンプを取得
        local prev_ts
        prev_ts=$(echo "$lines" | grep -oP '^\d{2}:\d{2}:\d{2}' | tail -1)
        echo "ERROR|停止|プロセスが終了しています||$prev_ts|"
    else
        echo "ACTIVE|稼働中|稼働中||$last_ts|"
    fi
}

# ステータスの色付け
colored_status() {
    local status="$1"
    local label="$2"
    case "$status" in
        BUSY)  printf "${YELLOW}● %-6s${RESET}" "$label" ;;
        DONE)  printf "${GREEN}✔ %-6s${RESET}" "$label" ;;
        ERROR) printf "${RED}✗ %-6s${RESET}" "$label" ;;
        WATCH) printf "${CYAN}◉ %-6s${RESET}" "$label" ;;
        IDLE)  printf "${DIM}○ %-6s${RESET}" "$label" ;;
        *)     printf "${GREEN}● %-6s${RESET}" "$label" ;;
    esac
}

# 文字列を指定幅に切り詰め
truncate() {
    local str="$1"
    local max="$2"
    if [ ${#str} -gt "$max" ]; then
        echo "${str:0:$((max-2))}.."
    else
        echo "$str"
    fi
}

# 共有ディレクトリの統計
count_files() {
    local dir="$1"
    if [ -d "$dir" ]; then
        find "$dir" -type f -name '*.md' 2>/dev/null | wc -l
    else
        echo "0"
    fi
}

# --- メイン出力 ---

echo ""
echo -e "${BOLD}  agent-corp ダッシュボード${RESET}  ${DIM}$(date '+%H:%M:%S')${RESET}"
echo -e "${DIM}  ─────────────────────────────────────────────────────────────────────────${RESET}"
echo ""

# ヘッダー
printf "  ${DIM}%-10s %-8s  %-32s %8s %10s${RESET}\n" "Agent" "Status" "Task" "開始" "経過/予測"
echo -e "  ${DIM}──────────────────────────────────────────────────────────────────────────${RESET}"

# 各エージェント
agents=(
    "CEO|${SESSION_NAME}:ceo.0"
    "PM|${SESSION_NAME}:pm.0"
    "Intern|${SESSION_NAME}:intern.0"
    "Frontend|${SESSION_NAME}:engineers.0"
    "Backend|${SESSION_NAME}:engineers.1"
    "Security|${SESSION_NAME}:engineers.2"
    "QA|${SESSION_NAME}:qa.0"
    "PO|${SESSION_NAME}:po.0"
    "PerfAnl|${SESSION_NAME}:perf.0"
)

for agent_info in "${agents[@]}"; do
    IFS='|' read -r name target <<< "$agent_info"
    _raw="$(get_status "$target")"

    # パース: STATUS|LABEL|DETAIL|START_TS|LAST_TS|TASK_FILE
    status="${_raw%%|*}"; _raw="${_raw#*|}"
    label="${_raw%%|*}"; _raw="${_raw#*|}"
    detail="${_raw%%|*}"; _raw="${_raw#*|}"
    start_ts="${_raw%%|*}"; _raw="${_raw#*|}"
    last_ts="${_raw%%|*}"; task_file="${_raw#*|}"

    detail=$(truncate "$detail" 32)

    # 時刻表示
    local_start=""
    local_elapsed=""
    if [ "$status" = "BUSY" ] && [ -n "$start_ts" ]; then
        local_start="$start_ts"
        local_elapsed=$(elapsed_from "$start_ts")
        elapsed_s=0
        if [ -n "$start_ts" ]; then
            elapsed_s=$(( $(date +%s) - $(date -d "$start_ts" +%s 2>/dev/null || echo "$(date +%s)") ))
        fi

        # 見積もり時間を取得して表示
        est_min=$(get_estimate_minutes "$task_file")
        if [ -n "$est_min" ]; then
            est_sec=$(( est_min * 60 ))
            if [ "$elapsed_s" -ge $(( est_sec * 3 / 2 )) ]; then
                # 1.5倍超過 → 赤
                local_elapsed="${RED}${local_elapsed}/${est_min}m${RESET}"
            elif [ "$elapsed_s" -ge "$est_sec" ]; then
                # 超過 → 黄
                local_elapsed="${YELLOW}${local_elapsed}/${est_min}m${RESET}"
            else
                local_elapsed="${local_elapsed}/${est_min}m"
            fi
        else
            # 見積もりなし: 従来の経過時間のみ
            if [ "$elapsed_s" -ge 600 ]; then
                local_elapsed="${RED}${local_elapsed}${RESET}"
            elif [ "$elapsed_s" -ge 300 ]; then
                local_elapsed="${YELLOW}${local_elapsed}${RESET}"
            fi
        fi
    elif [ -n "$last_ts" ]; then
        local_start=""
        local_elapsed="${DIM}$(elapsed_from "$last_ts") ago${RESET}"
    fi

    printf "  %-10s " "$name"
    colored_status "$status" "$label"
    printf "  %-32s " "$detail"
    printf "%8s " "$local_start"
    printf "%b\n" "${local_elapsed:-${DIM}-${RESET}}"
done

# --- 依頼サマリー（requirement 単位の見積もり集計） ---

# instruction ID → req_id マッピングを構築
declare -A INST_REF_MAP
for inf in "$SHARED"/instructions/pm/*.md; do
    [ -f "$inf" ] || continue
    _inst_fname=$(basename "$inf" .md)
    _ref_req=$(grep -m1 '^ref_requirement:' "$inf" 2>/dev/null | sed 's/^ref_requirement: *//')
    [ -n "$_ref_req" ] && INST_REF_MAP["$_inst_fname"]="$_ref_req"
done

# instruction ID から req_id を解決（直接マッチ or 同一プレフィクスの別 instruction 経由）
resolve_inst_to_req() {
    local inst_id="$1"
    # 直接マッチ
    [ -n "${INST_REF_MAP[$inst_id]}" ] && { echo "${INST_REF_MAP[$inst_id]}"; return; }
    # 同日のプレフィクス（例: 20260131-005）で他の instruction を探す
    local prefix="${inst_id%%-inst*}"
    for key in "${!INST_REF_MAP[@]}"; do
        [[ "$key" == "${prefix}-"* ]] && { echo "${INST_REF_MAP[$key]}"; return; }
    done
    echo ""
}

# task → ref_instruction → req_id を解決し、estimate を集計
declare -A REQ_EST_TOTAL      # req_id → total estimated minutes
declare -A REQ_EST_COUNT      # req_id → number of tasks with estimates
declare -A REQ_TASK_COUNT     # req_id → total task count
declare -A REQ_ACTUAL_TOTAL   # req_id → total actual minutes
declare -A REQ_ACTUAL_COUNT   # req_id → number of tasks with actuals
declare -A REQ_CREATED_AT     # req_id → created_at timestamp

# requirement の created_at を収集
for rf in "$SHARED"/requirements/*.md; do
    [ -f "$rf" ] || continue
    _rid=$(grep -m1 '^id:' "$rf" | sed 's/^id: *//')
    _created=$(grep -m1 '^created_at:' "$rf" | sed 's/^created_at: *//')
    [ -n "$_rid" ] && [ -n "$_created" ] && REQ_CREATED_AT["$_rid"]="$_created"
done

# タスクファイルを走査して estimate/actual を集計
for role_dir in "$SHARED"/tasks/*/; do
    [ -d "$role_dir" ] || continue
    _role=$(basename "$role_dir")
    for tf in "$role_dir"*.md; do
        [ -f "$tf" ] || continue
        _tf_base=$(basename "$tf" .md)

        # ref_instruction → req_id の解決（複数手段で試行）
        _req_id=""

        # 1) タスクファイル内の ref_instruction フィールド
        _ref_inst=$(grep -m1 '^ref_instruction:' "$tf" 2>/dev/null | sed 's/^ref_instruction: *//')
        if [ -n "$_ref_inst" ]; then
            _req_id=$(resolve_inst_to_req "$_ref_inst")
        fi

        # 2) タスクファイル内の ref_requirement フィールド
        if [ -z "$_req_id" ]; then
            _req_id=$(grep -m1 '^ref_requirement:' "$tf" 2>/dev/null | sed 's/^ref_requirement: *//')
        fi

        # 3) ファイル名から instruction ID を推定（例: 20260131-005-inst-task → 20260131-005-inst）
        if [ -z "$_req_id" ]; then
            _inferred_inst=$(echo "$_tf_base" | sed -n 's/-task$//p')
            if [ -n "$_inferred_inst" ] && [ -f "$SHARED/instructions/pm/${_inferred_inst}.md" ]; then
                _req_id=$(resolve_inst_to_req "$_inferred_inst")
            fi
        fi

        # 4) instruction ファイルを走査し、タスクファイル名の先頭部分で部分一致
        #    例: T-20260201-ENNEAGRAM-001-backend → 20260201-ENNEAGRAM-001-inst にマッチ
        if [ -z "$_req_id" ]; then
            for _inst_file in "$SHARED"/instructions/pm/*.md; do
                [ -f "$_inst_file" ] || continue
                _inst_base=$(basename "$_inst_file" .md)
                # instruction のコアID部分を抽出（例: 20260201-ENNEAGRAM-001）
                _inst_core=$(echo "$_inst_base" | sed 's/-inst$//' | sed 's/-req-instruction$//')
                [ -z "$_inst_core" ] && continue
                # タスクファイル名にコアIDが含まれるか
                if [[ "$_tf_base" == *"$_inst_core"* ]]; then
                    _inst_id=$(grep -m1 '^id:' "$_inst_file" 2>/dev/null | sed 's/^id: *//')
                    if [ -n "$_inst_id" ]; then
                        _req_id=$(resolve_inst_to_req "$_inst_base")
                        [ -n "$_req_id" ] && break
                    fi
                fi
            done
        fi

        [ -z "$_req_id" ] && continue

        # タスク数カウント
        REQ_TASK_COUNT["$_req_id"]=$(( ${REQ_TASK_COUNT[$_req_id]:-0} + 1 ))

        # estimate 集計
        _est_file="$SHARED/.estimates/$_role/${_tf_base}-estimate.json"
        if [ -f "$_est_file" ]; then
            _est_min=$(jq -r '.estimated_duration_minutes // empty' "$_est_file" 2>/dev/null)
            if [ -n "$_est_min" ]; then
                REQ_EST_TOTAL["$_req_id"]=$(( ${REQ_EST_TOTAL[$_req_id]:-0} + _est_min ))
                REQ_EST_COUNT["$_req_id"]=$(( ${REQ_EST_COUNT[$_req_id]:-0} + 1 ))
            fi
        fi

        # actual 集計
        _act_file="$SHARED/.estimates/$_role/${_tf_base}-actual.json"
        if [ -f "$_act_file" ]; then
            _act_min=$(jq -r '.actual_minutes // empty' "$_act_file" 2>/dev/null)
            if [ -n "$_act_min" ]; then
                REQ_ACTUAL_TOTAL["$_req_id"]=$(( ${REQ_ACTUAL_TOTAL[$_req_id]:-0} + ${_act_min%.*} ))
                REQ_ACTUAL_COUNT["$_req_id"]=$(( ${REQ_ACTUAL_COUNT[$_req_id]:-0} + 1 ))
            fi
        fi
    done
done

# 依頼サマリー表示
if [ ${#REQ_CREATED_AT[@]} -gt 0 ]; then
    echo ""
    echo -e "${DIM}  ─────────────────────────────────────────────────────────────────────────${RESET}"
    echo -e "  ${BOLD}依頼サマリー${RESET}"
    echo ""
    printf "  ${DIM}%-38s %6s %8s %8s %10s${RESET}\n" "依頼" "Tasks" "見積" "実績" "経過"
    echo -e "  ${DIM}──────────────────────────────────────────────────────────────────────────${RESET}"

    for rf in "$SHARED"/requirements/*.md; do
        [ -f "$rf" ] || continue
        _rid=$(grep -m1 '^id:' "$rf" | sed 's/^id: *//')
        [ -z "$_rid" ] && continue
        _rtitle=$(grep -m1 '^# ' "$rf" | sed 's/^# *//')
        _rtitle=$(truncate "$_rtitle" 36)
        _created="${REQ_CREATED_AT[$_rid]}"

        _task_cnt="${REQ_TASK_COUNT[$_rid]:-0}"
        _est_total="${REQ_EST_TOTAL[$_rid]:-0}"
        _est_cnt="${REQ_EST_COUNT[$_rid]:-0}"
        _act_total="${REQ_ACTUAL_TOTAL[$_rid]:-0}"
        _act_cnt="${REQ_ACTUAL_COUNT[$_rid]:-0}"

        # 見積もり表示
        if [ "$_est_cnt" -gt 0 ]; then
            if [ "$_est_total" -ge 60 ]; then
                _est_disp="$(( _est_total / 60 ))h$(( _est_total % 60 ))m"
            else
                _est_disp="${_est_total}m"
            fi
        else
            _est_disp="${DIM}-${RESET}"
        fi

        # 実績表示
        if [ "$_act_cnt" -gt 0 ]; then
            if [ "$_act_total" -ge 60 ]; then
                _act_disp="$(( _act_total / 60 ))h$(( _act_total % 60 ))m"
            else
                _act_disp="${_act_total}m"
            fi
        else
            _act_disp="${DIM}-${RESET}"
        fi

        # 経過時間計算（created_at からの経過）
        _elapsed_disp="${DIM}-${RESET}"
        if [ -n "$_created" ]; then
            _cr_s=$(date -d "$_created" +%s 2>/dev/null)
            if [ -n "$_cr_s" ]; then
                _now_s=$(date +%s)
                _diff=$(( _now_s - _cr_s ))
                if [ "$_diff" -ge 86400 ]; then
                    _elapsed_disp="$(( _diff / 86400 ))d$(( _diff % 86400 / 3600 ))h"
                elif [ "$_diff" -ge 3600 ]; then
                    _elapsed_disp="$(( _diff / 3600 ))h$(( _diff % 3600 / 60 ))m"
                elif [ "$_diff" -ge 60 ]; then
                    _elapsed_disp="$(( _diff / 60 ))m$(( _diff % 60 ))s"
                else
                    _elapsed_disp="${_diff}s"
                fi
            fi
        fi

        # タスク進捗色
        if [ "$_task_cnt" -eq 0 ]; then
            _cnt_disp="${DIM}0${RESET}"
        elif [ "$_act_cnt" -ge "$_task_cnt" ]; then
            _cnt_disp="${GREEN}${_act_cnt}/${_task_cnt}${RESET}"
        else
            _cnt_disp="${YELLOW}${_act_cnt}/${_task_cnt}${RESET}"
        fi

        printf "  %-38s %b %b %b %10s\n" "$_rtitle" "$_cnt_disp" "$_est_disp" "$_act_disp" "$_elapsed_disp"
    done
fi

echo ""
echo -e "${DIM}  ─────────────────────────────────────────────────────────────────────────${RESET}"

# 共有ディレクトリ統計
local_req=$(count_files "$SHARED/requirements")
local_inst=$(count_files "$SHARED/instructions/pm")
local_task=$(count_files "$SHARED/tasks")
local_report=$(count_files "$SHARED/reports")
local_bug=$(count_files "$SHARED/bugs")

echo -e "  ${DIM}要件:${RESET} ${local_req}  ${DIM}指示:${RESET} ${local_inst}  ${DIM}タスク:${RESET} ${local_task}  ${DIM}報告:${RESET} ${local_report}  ${DIM}バグ:${RESET} ${local_bug}"
echo ""
echo -e "  ${DIM}経過/予測: 超過=${RESET}${YELLOW}黄${RESET}  ${DIM}1.5x超過=${RESET}${RED}赤${RESET}  ${DIM}(見積もりなし: 5m=${RESET}${YELLOW}黄${RESET} ${DIM}10m=${RESET}${RED}赤${RESET}${DIM})${RESET}"

# --- 未処理タスクキュー ---
PROCESSED_DIR="$SHARED/.processed"

is_task_processed() {
    local file="$1"
    local hash=$(echo "$file" | md5sum | cut -d' ' -f1)
    [ -f "$PROCESSED_DIR/$hash" ]
}

# ロール別に未処理タスクを収集
declare -A QUEUE_ROLES
QUEUE_ROLES=(
    ["requirements"]="$SHARED/requirements"
    ["instructions"]="$SHARED/instructions/pm"
    ["frontend"]="$SHARED/tasks/frontend"
    ["backend"]="$SHARED/tasks/backend"
    ["security"]="$SHARED/tasks/security"
    ["qa"]="$SHARED/tasks/qa"
    ["po"]="$SHARED/tasks/po"
)

# requirement ID → タイトルのマッピングを構築
declare -A REQ_TITLES
for rf in "$SHARED"/requirements/*.md; do
    [ -f "$rf" ] || continue
    rid=$(grep -m1 '^id:' "$rf" | sed 's/^id: *//')
    rtitle=$(grep -m1 '^# ' "$rf" | sed 's/^# *//')
    [ -n "$rid" ] && REQ_TITLES["$rid"]="$rtitle"
done

# instruction ファイル → ref_requirement のマッピングを構築
declare -A INST_TO_REQ
for inf in "$SHARED"/instructions/pm/*.md; do
    [ -f "$inf" ] || continue
    inst_id=$(grep -m1 '^id:' "$inf" | sed 's/^id: *//')
    inst_fname=$(basename "$inf" .md)
    ref_req=$(grep -m1 '^ref_requirement:' "$inf" | sed 's/^ref_requirement: *//')
    [ -n "$ref_req" ] && {
        [ -n "$inst_id" ] && INST_TO_REQ["$inst_id"]="$ref_req"
        INST_TO_REQ["$inst_fname"]="$ref_req"
    }
done

# タスクファイルから元のrequirement IDを特定
resolve_req_id() {
    local file="$1"
    local fname
    fname=$(basename "$file")

    # 1) ref_instruction から辿る
    local ref_inst
    ref_inst=$(grep -m1 '^ref_instruction:' "$file" 2>/dev/null | sed 's/^ref_instruction: *//')
    if [ -n "$ref_inst" ]; then
        local req_id="${INST_TO_REQ[$ref_inst]}"
        if [ -n "$req_id" ]; then
            echo "$req_id"
            return
        fi
    fi

    # 2) ref_requirement が直接ある場合
    local ref_req
    ref_req=$(grep -m1 '^ref_requirement:' "$file" 2>/dev/null | sed 's/^ref_requirement: *//')
    if [ -n "$ref_req" ]; then
        echo "$ref_req"
        return
    fi

    # 3) ファイル名パターンによるヒューリスティック推測
    case "$fname" in
        *DEPLOY*|*deploy*)
            echo "__deploy__" ;;
        *SIGNIN-REDO*|*signin-redo*|*signin-commit*|*signin-cherry*|*signin-build*)
            echo "__signin_redo__" ;;
        *E2E*|*e2e*|*playwright*)
            echo "__e2e__" ;;
        *qa-login*|*qa_login*)
            echo "__qa__" ;;
        *)
            echo "" ;;
    esac
}

# 未処理タスクを収集し、依頼元ごとにグルーピング
total_pending=0
declare -A REQ_PENDING_ITEMS   # req_id → "role:title\n..."
declare -A REQ_PENDING_COUNT   # req_id → count
REQ_ORDER=()                   # 表示順序を保持
UNKNOWN_KEY="__unknown__"

for role in requirements instructions frontend backend security qa; do
    dir="${QUEUE_ROLES[$role]}"
    [ -d "$dir" ] || continue
    for f in "$dir"/*.md; do
        [ -f "$f" ] || continue
        is_task_processed "$f" && continue

        total_pending=$(( total_pending + 1 ))
        fname=$(basename "$f")
        title=$(get_task_title "$fname")
        if [ -z "$title" ]; then
            title=$(humanize_filename "$fname")
        fi
        title=$(truncate "$title" 40)

        req_id=$(resolve_req_id "$f")
        [ -z "$req_id" ] && req_id="$UNKNOWN_KEY"

        # 初出のreq_idなら順序を記録
        if [ -z "${REQ_PENDING_COUNT[$req_id]+x}" ]; then
            REQ_ORDER+=("$req_id")
            REQ_PENDING_COUNT["$req_id"]=0
            REQ_PENDING_ITEMS["$req_id"]=""
        fi
        REQ_PENDING_COUNT["$req_id"]=$(( ${REQ_PENDING_COUNT[$req_id]} + 1 ))
        REQ_PENDING_ITEMS["$req_id"]+="${role}|${title}\n"
    done
done

echo ""
echo -e "${DIM}  ─────────────────────────────────────────────────────────────────────────${RESET}"
if [ "$total_pending" -gt 0 ]; then
    echo -e "  ${BOLD}未処理キュー${RESET} ${YELLOW}${total_pending}件${RESET}"
    echo ""
    MAX_ITEMS=3
    for req_id in "${REQ_ORDER[@]}"; do
        count=${REQ_PENDING_COUNT[$req_id]}
        if [ "$req_id" = "$UNKNOWN_KEY" ]; then
            req_label="(依頼元不明)"
        elif [ "$req_id" = "__deploy__" ]; then
            req_label="本番デプロイ関連"
        elif [ "$req_id" = "__signin_redo__" ]; then
            req_label="ログイン機能とユーザー管理機能の追加（再指示）"
        elif [ "$req_id" = "__e2e__" ]; then
            req_label="ログイン機能のE2Eテスト作成"
        elif [ "$req_id" = "__qa__" ]; then
            req_label="ログイン機能の動作確認とバグ報告"
        else
            req_label="${REQ_TITLES[$req_id]}"
            [ -z "$req_label" ] && req_label="依頼: ${req_id:0:12}..."
        fi
        echo -e "  ${CYAN}▸${RESET} ${BOLD}${req_label}${RESET} ${DIM}(${count}件)${RESET}"
        echo -ne "${REQ_PENDING_ITEMS[$req_id]}" | head -n "$MAX_ITEMS" | while IFS='|' read -r r t; do
            [ -n "$t" ] && printf "    ${DIM}%-11s${RESET} %s\n" "$r" "$t"
        done
        if [ "$count" -gt "$MAX_ITEMS" ]; then
            echo -e "    ${DIM}...他$(( count - MAX_ITEMS ))件${RESET}"
        fi
    done
else
    echo -e "  ${BOLD}未処理キュー${RESET} ${GREEN}すべて処理済み${RESET}"
fi
echo ""
