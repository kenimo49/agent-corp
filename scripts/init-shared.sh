#!/bin/bash

# 共有ディレクトリの初期化スクリプト
# Usage: ./scripts/init-shared.sh [SHARED_DIR]

set -e

SHARED_DIR="${1:-./shared}"

echo "共有ディレクトリを初期化中: $SHARED_DIR"

# メインディレクトリ
mkdir -p "$SHARED_DIR"

# 要件（Human → CEO）
mkdir -p "$SHARED_DIR/requirements"

# 指示（CEO → PM）
mkdir -p "$SHARED_DIR/instructions/pm"

# タスク（PM → Engineers）
mkdir -p "$SHARED_DIR/tasks/frontend"
mkdir -p "$SHARED_DIR/tasks/backend"
mkdir -p "$SHARED_DIR/tasks/security"

# 報告（下位 → 上位）
mkdir -p "$SHARED_DIR/reports/human"
mkdir -p "$SHARED_DIR/reports/pm"
mkdir -p "$SHARED_DIR/reports/engineers/frontend"
mkdir -p "$SHARED_DIR/reports/engineers/backend"
mkdir -p "$SHARED_DIR/reports/engineers/security"

# 質問・回答
mkdir -p "$SHARED_DIR/questions/ceo-to-pm"
mkdir -p "$SHARED_DIR/questions/pm-to-frontend"
mkdir -p "$SHARED_DIR/questions/pm-to-backend"
mkdir -p "$SHARED_DIR/questions/pm-to-security"
mkdir -p "$SHARED_DIR/questions/frontend-to-backend"
mkdir -p "$SHARED_DIR/questions/backend-to-frontend"
mkdir -p "$SHARED_DIR/questions/backend-to-security"
mkdir -p "$SHARED_DIR/questions/security-to-backend"
mkdir -p "$SHARED_DIR/questions/answers"

# 仕様共有
mkdir -p "$SHARED_DIR/specs/api"
mkdir -p "$SHARED_DIR/specs/design"
mkdir -p "$SHARED_DIR/specs/requirements"

# 成果物
mkdir -p "$SHARED_DIR/artifacts/code"
mkdir -p "$SHARED_DIR/artifacts/docs"
mkdir -p "$SHARED_DIR/artifacts/reviews"

# ログ・アーカイブ
mkdir -p "$SHARED_DIR/logs"
mkdir -p "$SHARED_DIR/archive"

# .gitkeep作成（空ディレクトリをgitで管理）
find "$SHARED_DIR" -type d -empty -exec touch {}/.gitkeep \;

echo "完了: $(find "$SHARED_DIR" -type d | wc -l) ディレクトリを作成しました"
