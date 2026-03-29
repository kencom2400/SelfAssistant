#!/bin/bash

# TaskをEpicに紐づけるスクリプト
# 使用方法: ./scripts/jira/issues/link-task-to-epic.sh <task_key> <epic_key>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"

TASK_KEY="${1:-}"
EPIC_KEY="${2:-}"

if [ -z "$TASK_KEY" ] || [ -z "$EPIC_KEY" ]; then
  echo "❌ エラー: TaskキーとEpicキーを指定してください" >&2
  echo "使用方法: $0 <task_key> <epic_key>" >&2
  exit 1
fi

echo "🔄 ${TASK_KEY} を Epic ${EPIC_KEY} に紐づけ中..."

# 方法1: parent フィールド（Epic配下への正式な親子関係）
DATA=$(jq -n --arg epic_key "$EPIC_KEY" '{"fields": {"parent": {"key": $epic_key}}}')
if jira_api_call "PUT" "issue/${TASK_KEY}" "$DATA" > /dev/null 2>&1; then
  echo "✅ Epic '${EPIC_KEY}' に紐づけました"
  exit 0
fi

# 方法2: issueLink Relates（フォールバック）
DATA=$(jq -n \
  --arg task_key "$TASK_KEY" \
  --arg epic_key "$EPIC_KEY" \
  '{
    type: { name: "Relates" },
    inwardIssue:  { key: $epic_key },
    outwardIssue: { key: $task_key }
  }')
if jira_api_call "POST" "issueLink" "$DATA" > /dev/null 2>&1; then
  echo "✅ Epic '${EPIC_KEY}' に紐づけました (Relates)"
  exit 0
fi

echo "❌ 紐づけに失敗しました: ${TASK_KEY} → ${EPIC_KEY}" >&2
exit 1
