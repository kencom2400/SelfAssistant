#!/bin/bash

# プロジェクトで利用可能なIssue種別一覧を取得する
# 使用方法: ./scripts/jira/issues/get-issue-types.sh [project_key]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"

PROJECT_KEY="${1:-${JIRA_PROJECT_KEY:-SA}}"

echo "🔍 プロジェクト '${PROJECT_KEY}' のIssue種別を取得中..."

response=$(jira_api_call "GET" "issue/createmeta?projectKeys=${PROJECT_KEY}&expand=projects.issuetypes")

if [ $? -ne 0 ]; then
  echo "❌ Issue種別の取得に失敗しました" >&2
  exit 1
fi

echo ""
echo "利用可能なIssue種別:"
echo "$response" | jq -r '.projects[0].issuetypes[] | "  ID: \(.id)  名前: \(.name)"'
