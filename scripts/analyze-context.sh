#!/bin/bash

# analyze-context.sh - プロジェクトコンテキストを解析し、ナレッジファイルを生成
# Usage: ./analyze-context.sh [project_dir] [task_content]

set -e

PROJECT_DIR="${1:-.}"
TASK_CONTENT="${2:-}"
KNOWLEDGE_DIR="${AGENT_KNOWLEDGE_DIR:-$HOME/.agent-corp/knowledge}"
RAG_CONTEXT_MAX_LINES="${RAG_CONTEXT_MAX_LINES:-200}"

# プロジェクト識別子（パスのハッシュ）
PROJECT_HASH=$(echo "$(cd "$PROJECT_DIR" && pwd)" | md5sum | cut -d' ' -f1 | head -c 8)
PROJECT_KNOWLEDGE_DIR="$KNOWLEDGE_DIR/projects/$PROJECT_HASH"

mkdir -p "$PROJECT_KNOWLEDGE_DIR"
mkdir -p "$KNOWLEDGE_DIR/global"

# 1. ディレクトリ構造を生成
generate_structure() {
    echo "## ディレクトリ構造"
    echo ""
    echo '```'
    if command -v tree &>/dev/null; then
        tree -L 3 -I 'node_modules|.git|__pycache__|.venv|dist|build|.next|.cache|coverage' "$PROJECT_DIR" 2>/dev/null | head -80
    else
        # treeがない場合はfindで代替
        find "$PROJECT_DIR" -maxdepth 3 -type d \
            ! -path '*node_modules*' \
            ! -path '*.git*' \
            ! -path '*__pycache__*' \
            ! -path '*.venv*' \
            2>/dev/null | head -50
    fi
    echo '```'
}

# 2. 技術スタック推定
detect_tech_stack() {
    echo "## 技術スタック"
    echo ""

    local detected=false

    # Node.js / JavaScript / TypeScript
    if [ -f "$PROJECT_DIR/package.json" ]; then
        detected=true
        echo "### Node.js プロジェクト"
        echo ""

        # 主要な依存関係を抽出
        if command -v jq &>/dev/null; then
            echo "**依存関係:**"
            echo '```'
            jq -r '(.dependencies // {}) | keys[]' "$PROJECT_DIR/package.json" 2>/dev/null | head -15
            echo '```'
            echo ""

            echo "**開発依存関係:**"
            echo '```'
            jq -r '(.devDependencies // {}) | keys[]' "$PROJECT_DIR/package.json" 2>/dev/null | head -10
            echo '```'

            # スクリプト
            echo ""
            echo "**npm scripts:**"
            echo '```'
            jq -r '(.scripts // {}) | to_entries[] | "- \(.key): \(.value)"' "$PROJECT_DIR/package.json" 2>/dev/null | head -10
            echo '```'
        else
            echo '```'
            head -30 "$PROJECT_DIR/package.json"
            echo '```'
        fi
        echo ""
    fi

    # TypeScript
    if [ -f "$PROJECT_DIR/tsconfig.json" ]; then
        echo "**TypeScript設定あり** (tsconfig.json)"
        echo ""
    fi

    # Python
    if [ -f "$PROJECT_DIR/requirements.txt" ]; then
        detected=true
        echo "### Python プロジェクト"
        echo ""
        echo "**requirements.txt:**"
        echo '```'
        head -15 "$PROJECT_DIR/requirements.txt"
        echo '```'
        echo ""
    fi

    if [ -f "$PROJECT_DIR/pyproject.toml" ]; then
        detected=true
        echo "### Python プロジェクト (pyproject.toml)"
        echo ""
        echo '```'
        head -30 "$PROJECT_DIR/pyproject.toml"
        echo '```'
        echo ""
    fi

    # Go
    if [ -f "$PROJECT_DIR/go.mod" ]; then
        detected=true
        echo "### Go プロジェクト"
        echo ""
        echo '```'
        head -20 "$PROJECT_DIR/go.mod"
        echo '```'
        echo ""
    fi

    # Rust
    if [ -f "$PROJECT_DIR/Cargo.toml" ]; then
        detected=true
        echo "### Rust プロジェクト"
        echo ""
        echo '```'
        head -20 "$PROJECT_DIR/Cargo.toml"
        echo '```'
        echo ""
    fi

    # Docker
    if [ -f "$PROJECT_DIR/Dockerfile" ] || [ -f "$PROJECT_DIR/docker-compose.yml" ] || [ -f "$PROJECT_DIR/docker-compose.yaml" ]; then
        echo "**Docker対応** (Dockerfile/docker-compose あり)"
        echo ""
    fi

    if [ "$detected" = false ]; then
        echo "（技術スタックを自動検出できませんでした）"
        echo ""
    fi
}

# 3. 関連ファイル検索（タスク内容がある場合）
find_related_files() {
    if [ -z "$TASK_CONTENT" ]; then
        return
    fi

    echo "## タスク関連ファイル"
    echo ""

    # タスク内容からキーワード抽出（4文字以上の英単語）
    local keywords=$(echo "$TASK_CONTENT" | grep -oE '[A-Za-z]{4,}' | sort -u | head -8)

    if [ -z "$keywords" ]; then
        echo "（キーワードが抽出できませんでした）"
        echo ""
        return
    fi

    echo "**検索キーワード:** $keywords"
    echo ""

    local found_files=""
    for kw in $keywords; do
        local files=$(grep -rl "$kw" "$PROJECT_DIR" \
            --include="*.ts" --include="*.tsx" \
            --include="*.js" --include="*.jsx" \
            --include="*.py" \
            --include="*.go" \
            --include="*.rs" \
            --include="*.md" \
            2>/dev/null | \
            grep -v 'node_modules' | \
            grep -v '.git' | \
            head -5)

        if [ -n "$files" ]; then
            found_files="$found_files $files"
        fi
    done

    # 重複を除去して表示
    if [ -n "$found_files" ]; then
        echo "**関連ファイル:**"
        echo '```'
        echo "$found_files" | tr ' ' '\n' | sort -u | head -15
        echo '```'
    else
        echo "（関連ファイルが見つかりませんでした）"
    fi
    echo ""
}

# 4. 主要ドキュメント読み込み
read_docs() {
    echo "## プロジェクトドキュメント"
    echo ""

    local docs_found=false

    # README.md
    if [ -f "$PROJECT_DIR/README.md" ]; then
        docs_found=true
        echo "### README.md（抜粋）"
        echo ""
        echo '```markdown'
        head -50 "$PROJECT_DIR/README.md"
        echo '```'
        echo ""
    fi

    # CLAUDE.md / AGENTS.md
    for doc in CLAUDE.md AGENTS.md; do
        if [ -f "$PROJECT_DIR/$doc" ]; then
            docs_found=true
            echo "### $doc（抜粋）"
            echo ""
            echo '```markdown'
            head -80 "$PROJECT_DIR/$doc"
            echo '```'
            echo ""
        fi
    done

    if [ "$docs_found" = false ]; then
        echo "（プロジェクトドキュメントが見つかりませんでした）"
        echo ""
    fi
}

# 5. 既存のAPIエンドポイント検出（該当する場合）
detect_api_endpoints() {
    local api_files=""

    # Expressスタイル
    api_files=$(grep -rl "app\.\(get\|post\|put\|delete\|patch\)" "$PROJECT_DIR" \
        --include="*.ts" --include="*.js" 2>/dev/null | \
        grep -v 'node_modules' | head -5)

    # Fastifyスタイル
    if [ -z "$api_files" ]; then
        api_files=$(grep -rl "fastify\.\(get\|post\|put\|delete\)" "$PROJECT_DIR" \
            --include="*.ts" --include="*.js" 2>/dev/null | \
            grep -v 'node_modules' | head -5)
    fi

    if [ -n "$api_files" ]; then
        echo "## API エンドポイント"
        echo ""
        echo "**APIルートファイル:**"
        echo '```'
        echo "$api_files"
        echo '```'
        echo ""

        # 最初のファイルからエンドポイントを抽出
        local first_file=$(echo "$api_files" | head -1)
        if [ -f "$first_file" ]; then
            echo "**エンドポイント例 ($first_file):**"
            echo '```'
            grep -E "(get|post|put|delete|patch)\s*\(['\"/]" "$first_file" 2>/dev/null | head -10
            echo '```'
            echo ""
        fi
    fi
}

# 6. データベーススキーマ検出
detect_db_schema() {
    local schema_files=""

    # SQLファイル
    schema_files=$(find "$PROJECT_DIR" -name "*.sql" -type f 2>/dev/null | \
        grep -v 'node_modules' | head -3)

    # Prismaスキーマ
    if [ -f "$PROJECT_DIR/prisma/schema.prisma" ]; then
        echo "## データベーススキーマ (Prisma)"
        echo ""
        echo '```prisma'
        head -50 "$PROJECT_DIR/prisma/schema.prisma"
        echo '```'
        echo ""
    elif [ -n "$schema_files" ]; then
        echo "## データベーススキーマ (SQL)"
        echo ""
        for schema in $schema_files; do
            echo "### $(basename "$schema")"
            echo '```sql'
            head -40 "$schema"
            echo '```'
            echo ""
        done
    fi
}

# 7. グローバルナレッジの読み込み（存在する場合）
include_global_knowledge() {
    if [ -d "$KNOWLEDGE_DIR/global" ]; then
        local global_files=$(find "$KNOWLEDGE_DIR/global" -name "*.md" -type f 2>/dev/null | head -5)
        if [ -n "$global_files" ]; then
            echo "## グローバルナレッジ"
            echo ""
            for gfile in $global_files; do
                local basename=$(basename "$gfile" .md)
                echo "### $basename"
                echo ""
                head -30 "$gfile"
                echo ""
            done
        fi
    fi
}

# メイン: コンテキスト生成
generate_context() {
    {
        echo "# プロジェクトコンテキスト"
        echo ""
        echo "**生成日時:** $(date '+%Y-%m-%d %H:%M:%S')"
        echo "**プロジェクトパス:** $(cd "$PROJECT_DIR" && pwd)"
        echo ""
        echo "---"
        echo ""

        generate_structure
        echo ""

        detect_tech_stack
        echo ""

        find_related_files
        echo ""

        detect_api_endpoints
        echo ""

        detect_db_schema
        echo ""

        read_docs
        echo ""

        include_global_knowledge

    } | head -$RAG_CONTEXT_MAX_LINES
}

# 出力生成
output_file="$PROJECT_KNOWLEDGE_DIR/context-cache.md"
generate_context > "$output_file"

# 結果を標準出力にも出力
cat "$output_file"
