#!/bin/bash

# Phase単位でJIRAチケットを一括作成するスクリプト
# 使用方法: ./scripts/jira/create-phase-tickets.sh <phase_num>
# 例:       ./scripts/jira/create-phase-tickets.sh 1

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/common.sh"

PHASE_NUM="${1:-}"

if [ -z "$PHASE_NUM" ]; then
  echo "❌ エラー: フェーズ番号を指定してください" >&2
  echo "使用方法: $0 <phase_num>" >&2
  exit 1
fi

TICKETS_YAML="${REPO_ROOT}/data/jira/phase${PHASE_NUM}-tickets.yaml"

if [ ! -f "$TICKETS_YAML" ]; then
  echo "❌ エラー: チケット定義ファイルが見つかりません: ${TICKETS_YAML}" >&2
  exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Phase ${PHASE_NUM} チケット一括作成"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 一時ディレクトリ
TEMP_DIR=$(mktemp -d)
trap "rm -rf ${TEMP_DIR}" EXIT INT TERM

# YAMLをパースしてEpicとTaskの情報を抽出
python3 << PYTHON_SCRIPT
import yaml
import os
import sys

yaml_path = "${TICKETS_YAML}"
temp_dir  = "${TEMP_DIR}"

with open(yaml_path, "r", encoding="utf-8") as f:
    data = yaml.safe_load(f)

# Epic情報を保存
epic = data.get("epic", {})
with open(os.path.join(temp_dir, "epic_title.txt"), "w") as f:
    f.write(epic.get("title", ""))
with open(os.path.join(temp_dir, "epic_body.txt"), "w") as f:
    f.write(epic.get("description", ""))

# Task情報を保存
tasks = data.get("tasks", [])
with open(os.path.join(temp_dir, "task_count.txt"), "w") as f:
    f.write(str(len(tasks)))

for task in tasks:
    task_id = task["id"]
    with open(os.path.join(temp_dir, f"task_{task_id}_title.txt"), "w") as f:
        f.write(task.get("title", ""))
    with open(os.path.join(temp_dir, f"task_{task_id}_body.txt"), "w") as f:
        f.write(task.get("description", ""))

print(f"Epicと{len(tasks)}件のTaskを読み込みました")
PYTHON_SCRIPT

EPIC_TITLE=$(cat "${TEMP_DIR}/epic_title.txt")
TASK_COUNT=$(cat "${TEMP_DIR}/task_count.txt")

echo "Epic: ${EPIC_TITLE}"
echo "Tasks: ${TASK_COUNT}件"
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 1. Epic を作成
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "🔄 Epicを作成中..."
EPIC_OUTPUT=$("${SCRIPT_DIR}/issues/create-issue.sh" \
  --title "$EPIC_TITLE" \
  --issue-type エピック \
  --body-file "${TEMP_DIR}/epic_body.txt" \
  --status ToDo)

EPIC_KEY=$(echo "$EPIC_OUTPUT" | grep "Issueキー:" | sed 's/.*Issueキー: //')
EPIC_URL=$(echo "$EPIC_OUTPUT" | grep "URL:" | sed 's/.*URL: //')

if [ -z "$EPIC_KEY" ]; then
  echo "❌ Epicの作成に失敗しました" >&2
  exit 1
fi

echo "✅ Epic作成完了: ${EPIC_KEY}"
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 2. Task を順番に作成
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Task作成 (${TASK_COUNT}件)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

CREATED_TASKS=()
FAILED_TASKS=()

for i in $(seq 1 "$TASK_COUNT"); do
  TASK_TITLE_FILE="${TEMP_DIR}/task_${i}_title.txt"
  TASK_BODY_FILE="${TEMP_DIR}/task_${i}_body.txt"

  if [ ! -f "$TASK_TITLE_FILE" ]; then
    continue
  fi

  TASK_TITLE=$(cat "$TASK_TITLE_FILE")
  echo "作成中 [${i}/${TASK_COUNT}]: ${TASK_TITLE}"

  TASK_OUTPUT=$("${SCRIPT_DIR}/issues/create-issue.sh" \
    --title "$TASK_TITLE" \
    --issue-type タスク \
    --body-file "$TASK_BODY_FILE" \
    --status ToDo 2>&1) || true

  TASK_KEY=$(echo "$TASK_OUTPUT" | grep "Issueキー:" | sed 's/.*Issueキー: //')

  if [ -n "$TASK_KEY" ]; then
    CREATED_TASKS+=("$TASK_KEY")
    echo "  ✅ ${TASK_KEY}"
  else
    FAILED_TASKS+=("Task ${i}")
    echo "  ❌ 作成失敗"
    echo "$TASK_OUTPUT" | grep -E "(エラー|Error|error)" | head -2
  fi

  sleep 0.5
done

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 3. Task を Epic に紐づけ
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if [ ${#CREATED_TASKS[@]} -gt 0 ]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Epic への紐づけ (${#CREATED_TASKS[@]}件)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  LINK_SUCCESS=0
  LINK_FAIL=0

  for TASK_KEY in "${CREATED_TASKS[@]}"; do
    if "${SCRIPT_DIR}/issues/link-task-to-epic.sh" "$TASK_KEY" "$EPIC_KEY" 2>/dev/null; then
      LINK_SUCCESS=$((LINK_SUCCESS + 1))
    else
      echo "  ⚠️  ${TASK_KEY} の紐づけに失敗しました"
      LINK_FAIL=$((LINK_FAIL + 1))
    fi
    sleep 0.3
  done

  echo ""
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 4. 結果サマリー
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Phase ${PHASE_NUM} チケット作成完了"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Epic:  ${EPIC_KEY}"
echo "URL:   ${EPIC_URL}"
echo ""
echo "作成済みTask (${#CREATED_TASKS[@]}件):"
for TASK_KEY in "${CREATED_TASKS[@]}"; do
  echo "  - ${TASK_KEY}  ${JIRA_BASE_URL}/browse/${TASK_KEY}"
done

if [ ${#FAILED_TASKS[@]} -gt 0 ]; then
  echo ""
  echo "⚠️  作成失敗 (${#FAILED_TASKS[@]}件): ${FAILED_TASKS[*]}"
fi

if [ "${LINK_FAIL:-0}" -gt 0 ]; then
  echo ""
  echo "⚠️  紐づけ失敗: ${LINK_FAIL}件（JIRAで手動紐づけが必要です）"
fi
