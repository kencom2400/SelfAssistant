#!/bin/bash

# JIRA API共通関数
# このファイルは他のJIRAスクリプトからsourceして使用します

# 設定ファイルの読み込み（config.local.sh > config.sh の優先順位）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/config.local.sh" ]; then
  source "${SCRIPT_DIR}/config.local.sh"
elif [ -f "${SCRIPT_DIR}/config.sh" ]; then
  source "${SCRIPT_DIR}/config.sh"
fi

# JIRA_BASE_URL のデフォルト値
if [ -z "${JIRA_BASE_URL:-}" ]; then
  export JIRA_BASE_URL='https://kencom2400.atlassian.net'
fi

# 認証情報の確認
check_jira_auth() {
  if [ -z "${JIRA_EMAIL:-}" ] || [ -z "${JIRA_API_TOKEN:-}" ]; then
    echo "❌ エラー: 環境変数 JIRA_EMAIL と JIRA_API_TOKEN が設定されていません。" >&2
    echo "" >&2
    echo "以下の手順で設定してください:" >&2
    echo "  1. cp scripts/jira/config.local.sh.example scripts/jira/config.local.sh" >&2
    echo "  2. scripts/jira/config.local.sh を編集して認証情報を入力" >&2
    exit 1
  fi
}

# Basic認証ヘッダーの生成
get_auth_header() {
  check_jira_auth
  echo -n "${JIRA_EMAIL}:${JIRA_API_TOKEN}" | base64
}

# JIRA API呼び出し共通関数
# 引数: method endpoint [data]
# 戻り値: レスポンスJSON（2xx以外はエラー終了）
jira_api_call() {
  local method="${1:-GET}"
  local endpoint="$2"
  local data="${3:-}"

  check_jira_auth

  local auth_header
  auth_header=$(get_auth_header)
  local url="${JIRA_BASE_URL}/rest/api/3/${endpoint}"

  local curl_args=(
    -s
    -X "$method"
    -H "Authorization: Basic ${auth_header}"
    -H "Accept: application/json"
    -H "Content-Type: application/json"
  )

  if [ -n "$data" ]; then
    curl_args+=(-d "$data")
  fi

  local response
  local http_code
  response=$(curl -w "\n%{http_code}" "${curl_args[@]}" "$url" 2>&1)
  http_code=$(echo "$response" | tail -n1)
  local response_body
  response_body=$(echo "$response" | sed '$d')

  if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
    echo "$response_body"
  else
    echo "HTTPエラー: $http_code" >&2
    echo "$response_body" >&2
    return 1
  fi
}

# エラーレスポンスの解析・表示
handle_jira_error() {
  local response="$1"
  local error_message
  error_message=$(echo "$response" | jq -r '.errorMessages[]? // .errors | to_entries[]? | "\(.key): \(.value)"' 2>/dev/null)

  if [ -n "$error_message" ]; then
    echo "❌ JIRA APIエラー:" >&2
    echo "$error_message" >&2
    return 1
  fi
}

# Issue種別IDをAPIから動的に取得
# 引数: project_key issue_type_name
get_issue_type_id_from_api() {
  local project_key="$1"
  local issue_type_name="$2"

  if [ -z "$project_key" ] || [ -z "$issue_type_name" ]; then
    return 1
  fi

  local issue_types_data
  issue_types_data=$(jira_api_call "GET" "issue/createmeta?projectKeys=${project_key}&expand=projects.issuetypes") || return 1

  local issue_type_id
  issue_type_id=$(echo "$issue_types_data" | jq -r --arg name "$issue_type_name" \
    '.projects[0].issuetypes[] | select(.name | test($name; "i")) | .id' | head -n 1)

  if [ -z "$issue_type_id" ] || [ "$issue_type_id" = "null" ]; then
    return 1
  fi

  echo "$issue_type_id"
}

# ステータス名の正規化（英語→日本語）
map_status_name() {
  local status_name="$1"
  local normalized
  normalized=$(echo "$status_name" | tr '[:upper:]' '[:lower:]' | sed 's/[[:space:]_]//g')

  case "$normalized" in
    "todo") echo "To Do" ;;
    "inprogress") echo "進行中" ;;
    "done") echo "完了" ;;
    "backlog") echo "バックログ" ;;
    *) echo "$status_name" ;;
  esac
}
