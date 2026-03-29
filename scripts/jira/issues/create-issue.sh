#!/bin/bash

# JIRAチケット作成スクリプト
# 使用方法:
#   バッチモード:
#     ./scripts/jira/issues/create-issue.sh \
#       --title "タイトル" --issue-type Task [オプション]
#
#   オプション:
#     --title TEXT          タイトル（必須）
#     --body TEXT           本文
#     --body-file FILE      本文をファイルから読み込み
#     --issue-type TYPE     Epic / Task（必須）
#     --status STATUS       ToDo / In Progress / Done
#     --project-key KEY     プロジェクトキー（省略時は config.sh の値）
#     --parent PARENT_KEY   親EpicのキーID

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"

# 引数解析
PROJECT_KEY="${JIRA_PROJECT_KEY:-SA}"
ISSUE_TYPE=""
TITLE=""
BODY=""
BODY_FILE=""
STATUS=""
PARENT_KEY=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --project-key) PROJECT_KEY="$2"; shift 2 ;;
    --issue-type)  ISSUE_TYPE="$2";  shift 2 ;;
    --title)       TITLE="$2";       shift 2 ;;
    --body)        BODY="$2";        shift 2 ;;
    --body-file)
      if [ ! -f "$2" ]; then
        echo "❌ エラー: ファイルが見つかりません: $2" >&2; exit 1
      fi
      BODY_FILE="$2"; shift 2 ;;
    --status)  STATUS="$2";     shift 2 ;;
    --parent)  PARENT_KEY="$2"; shift 2 ;;
    --help)
      sed -n '2,15p' "$0"; exit 0 ;;
    *)
      echo "❌ エラー: 不明なオプション: $1" >&2; exit 1 ;;
  esac
done

# 必須項目チェック
if [ -z "$TITLE" ] || [ -z "$ISSUE_TYPE" ]; then
  echo "❌ エラー: --title と --issue-type は必須です" >&2; exit 1
fi

# 本文の取得
if [ -n "$BODY_FILE" ]; then
  BODY=$(cat "$BODY_FILE")
elif [ -z "$BODY" ]; then
  BODY="（本文未設定）"
fi

# Issue種別IDを動的取得
echo "🔄 Issue種別IDを取得中..."
ISSUE_TYPE_ID=$(get_issue_type_id_from_api "$PROJECT_KEY" "$ISSUE_TYPE") || {
  echo "❌ Issue種別 '${ISSUE_TYPE}' が見つかりません。利用可能な種別:" >&2
  "${SCRIPT_DIR}/get-issue-types.sh" "$PROJECT_KEY" >&2
  exit 1
}
echo "✅ Issue種別ID: ${ISSUE_TYPE_ID} (${ISSUE_TYPE})"

# JSONペイロード構築（Atlassian Document Format）
ISSUE_DATA=$(jq -n \
  --arg project_key "$PROJECT_KEY" \
  --arg issue_type_id "$ISSUE_TYPE_ID" \
  --arg title "$TITLE" \
  --arg body "$BODY" \
  '{
    fields: {
      project: { key: $project_key },
      issuetype: { id: $issue_type_id },
      summary: $title,
      description: {
        type: "doc",
        version: 1,
        content: [{
          type: "paragraph",
          content: [{ type: "text", text: $body }]
        }]
      }
    }
  }')

# チケット作成
echo "🔄 チケットを作成中..."
RESPONSE=$(jira_api_call "POST" "issue" "$ISSUE_DATA")

ISSUE_KEY=$(echo "$RESPONSE" | jq -r '.key')
ISSUE_URL="${JIRA_BASE_URL}/browse/${ISSUE_KEY}"

echo "✅ 作成成功"
echo "Issueキー: ${ISSUE_KEY}"
echo "URL: ${ISSUE_URL}"

# ステータス遷移
if [ -n "$STATUS" ]; then
  MAPPED_STATUS=$(map_status_name "$STATUS")
  # トランジション一覧を取得してIDを特定
  TRANSITIONS=$(jira_api_call "GET" "issue/${ISSUE_KEY}/transitions")
  TRANSITION_ID=$(echo "$TRANSITIONS" | jq -r --arg s "$MAPPED_STATUS" \
    '.transitions[] | select(.name | test($s; "i")) | .id' | head -1)

  if [ -n "$TRANSITION_ID" ] && [ "$TRANSITION_ID" != "null" ]; then
    TRANS_DATA=$(jq -n --arg id "$TRANSITION_ID" '{"transition": {"id": $id}}')
    jira_api_call "POST" "issue/${ISSUE_KEY}/transitions" "$TRANS_DATA" > /dev/null
    echo "✅ ステータスを '${MAPPED_STATUS}' に変更しました"
  fi
fi

# 親Epicへの紐づけ
if [ -n "$PARENT_KEY" ]; then
  "${SCRIPT_DIR}/link-task-to-epic.sh" "$ISSUE_KEY" "$PARENT_KEY"
fi
