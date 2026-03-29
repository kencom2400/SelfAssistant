#!/bin/bash

# チケットを親チケットに紐づけるスクリプト（issueLink Relates 方式）
# 使用方法: ./scripts/jira/issues/link-task-to-epic.sh <task_key> <parent_key>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"

TASK_KEY="${1:-}"
PARENT_KEY="${2:-}"

if [ -z "$TASK_KEY" ] || [ -z "$PARENT_KEY" ]; then
  echo "❌ エラー: TaskキーとParentキーを指定してください" >&2
  echo "使用方法: $0 <task_key> <parent_key>" >&2
  exit 1
fi

echo "🔄 ${TASK_KEY} を ${PARENT_KEY} に紐づけ中..."

DATA=$(jq -n \
  --arg task_key "$TASK_KEY" \
  --arg parent_key "$PARENT_KEY" \
  '{
    type: { name: "Relates" },
    inwardIssue:  { key: $parent_key },
    outwardIssue: { key: $task_key }
  }')

if jira_api_call "POST" "issueLink" "$DATA" > /dev/null; then
  echo "✅ '${PARENT_KEY}' に紐づけました"
  exit 0
fi

echo "❌ 紐づけに失敗しました: ${TASK_KEY} → ${PARENT_KEY}" >&2
exit 1
