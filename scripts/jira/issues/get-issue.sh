#!/bin/bash

# JIRAチケット情報を取得する
# 使用方法: ./scripts/jira/issues/get-issue.sh <issue_key>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"

ISSUE_KEY="${1:-}"

if [ -z "$ISSUE_KEY" ]; then
  echo "❌ エラー: Issueキーを引数として指定してください" >&2
  echo "使用方法: $0 <issue_key>" >&2
  exit 1
fi

response=$(jira_api_call "GET" "issue/${ISSUE_KEY}")

if [ $? -ne 0 ]; then
  echo "❌ チケットの取得に失敗しました: ${ISSUE_KEY}" >&2
  exit 1
fi

echo "$response" | jq '{
  key: .key,
  summary: .fields.summary,
  status: .fields.status.name,
  issuetype: .fields.issuetype.name,
  assignee: (.fields.assignee.displayName // "未割当"),
  created: .fields.created,
  updated: .fields.updated
}'
