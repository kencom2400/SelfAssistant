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

# 方法1: parent フィールドで親を指定
DATA=$(jq -n --arg epic_key "$EPIC_KEY" '{"fields": {"parent": {"key": $epic_key}}}')
if jira_api_call "PUT" "issue/${TASK_KEY}" "$DATA" > /dev/null 2>&1; then
  echo "✅ Epic '${EPIC_KEY}' に紐づけました (parent フィールド)"
  exit 0
fi

# 方法2: customfield_10014（Epic Link）を使用
DATA=$(jq -n --arg epic_key "$EPIC_KEY" '{"fields": {"customfield_10014": $epic_key}}')
if jira_api_call "PUT" "issue/${TASK_KEY}" "$DATA" > /dev/null 2>&1; then
  echo "✅ Epic '${EPIC_KEY}' に紐づけました (Epic Link フィールド)"
  exit 0
fi

echo "⚠️  自動紐づけに失敗しました。JIRAで手動紐づけを行ってください: ${TASK_KEY} → ${EPIC_KEY}" >&2
exit 1
