# 002 - JIRA管理 実装設計書

## 対象

`002-jira-management-plan.md` に基づき、以下を実装する。

- `scripts/jira/` 以下のシェルスクリプト群
- Phase 1 チケット定義ファイル
- 一括チケット作成スクリプト

---

## 1. ファイル構成と実装内容

```
scripts/
└── jira/
    ├── common.sh                    # 共通関数
    ├── config.sh                    # 共通設定
    ├── config.local.sh.example     # 認証情報テンプレート
    ├── issues/
    │   ├── create-issue.sh         # チケット作成
    │   ├── get-issue.sh            # チケット参照
    │   ├── get-issue-types.sh      # Issue種別一覧
    │   └── link-task-to-epic.sh    # Epicへの紐づけ
    └── create-phase-tickets.sh     # Phase単位の一括作成

data/
└── jira/
    └── phase1-tickets.yaml         # Phase 1 チケット定義
```

---

## 2. 各ファイルの実装仕様

### 2.1 `scripts/jira/config.sh`

```bash
#!/bin/bash
export JIRA_BASE_URL='https://kencom2400.atlassian.net'
export JIRA_PROJECT_KEY='SA'
```

### 2.2 `scripts/jira/config.local.sh.example`

```bash
#!/bin/bash
# このファイルをコピーして config.local.sh を作成してください
# cp scripts/jira/config.local.sh.example scripts/jira/config.local.sh

export JIRA_EMAIL='your-email@example.com'
export JIRA_API_TOKEN='your-api-token'
```

### 2.3 `scripts/jira/common.sh`

MrWebDefence-Engine の実装をベースに以下の関数を提供する。

```bash
#!/bin/bash
# 設定ファイルの読み込み（config.local.sh > config.sh の優先順位）
# check_jira_auth()        - 認証情報の存在確認
# get_auth_header()        - Base64 Basic認証ヘッダー生成
# jira_api_call()          - REST API呼び出し共通関数
#   引数: method endpoint [data]
#   戻り値: レスポンスJSON（2xx以外はエラー終了）
# handle_jira_error()      - エラーレスポンス解析・表示
# get_issue_type_id_from_api() - Issue種別IDの動的取得
#   引数: project_key issue_type_name
# map_status_name()        - ステータス名正規化（英語→日本語）
```

### 2.4 `scripts/jira/issues/create-issue.sh`

```bash
# 使用方法（バッチモード）
./scripts/jira/issues/create-issue.sh \
  --title "タイトル" \
  --issue-type Task \
  --body "説明文" \
  --status ToDo \
  --project-key SA

# オプション一覧
# --title TEXT          タイトル（必須）
# --body TEXT           本文
# --body-file FILE      本文をファイルから読み込み
# --issue-type TYPE     Epic / Task（必須）
# --status STATUS       ToDo / In Progress / Done
# --project-key KEY     プロジェクトキー（省略時は config.sh の値）
# --parent PARENT_KEY   親EpicのキーID（指定時は自動紐づけ）

# 出力（成功時）
# Issueキー: SA-1
# URL: https://kencom2400.atlassian.net/browse/SA-1
```

### 2.5 `scripts/jira/issues/get-issue.sh`

```bash
# 使用方法
./scripts/jira/issues/get-issue.sh SA-1

# 出力: JSON形式のIssue情報
```

### 2.6 `scripts/jira/issues/get-issue-types.sh`

```bash
# 使用方法
./scripts/jira/issues/get-issue-types.sh SA

# 出力: プロジェクトで使用可能なIssue種別の一覧（ID + 名前）
```

### 2.7 `scripts/jira/issues/link-task-to-epic.sh`

```bash
# 使用方法
./scripts/jira/issues/link-task-to-epic.sh SA-2 SA-1
# TaskキーSA-2 を EpicキーSA-1 に紐づける

# 紐づけ方法（順に試行）
# 1. parent フィールドで親を指定
# 2. customfield_10014（Epic Link）を使用
```

---

## 3. Phase 1 チケット定義ファイル

### `data/jira/phase1-tickets.yaml`

```yaml
epic:
  title: "Phase 1: CLIエージェントエンジン基盤構築"
  description: |
    SelfAssistantのPhase 1実装。
    LangGraph + Claude API を使用したCLI会話エンジンの基盤を構築する。
    Working Memory / Short-term Memory / Long-term Memory（ChromaDB）を実装し、
    GeneralAgentによる汎用会話とセッション永続化を実現する。

tasks:
  - id: 1
    title: "Task 1: 環境構築（pyenv + poetry + pyproject.toml）"
    description: |
      ## 実装内容
      - pyenv local 3.12.12 の設定
      - poetry によるプロジェクト初期化
      - pyproject.toml への依存パッケージ定義
      - .env.example の作成

      ## 完了基準
      - poetry install が正常に完了する
      - poetry run python --version が 3.12.x を返す

  - id: 2
    title: "Task 2: 設定管理（src/config/settings.py）"
    description: |
      ## 実装内容
      - pydantic-settings による Settings クラスの実装
      - .env からの環境変数ロード
      - ANTHROPIC_API_KEY / MODEL / DB_PATH / CHROMA_PATH 等の定義

      ## 完了基準
      - tests/unit/test_settings.py がパスする
      - .env 未設定時にわかりやすいエラーが出る

  - id: 3
    title: "Task 3: Embeddingsモジュール（src/memory/embeddings.py）"
    description: |
      ## 実装内容
      - sentence-transformers の EmbeddingModel ラッパー実装
      - モデル: intfloat/multilingual-e5-small
      - encode() / encode_batch() メソッドの実装
      - モデルの遅延ロード（初回アクセス時に初期化）

      ## 完了基準
      - tests/unit/test_embeddings.py がパスする
      - encode() がfloatのリストを返す

  - id: 4
    title: "Task 4: データベース基盤（src/tools/database.py）"
    description: |
      ## 実装内容
      - SQLAlchemy + aiosqlite による非同期SQLiteアクセス
      - data/assistant.db の初期化・マイグレーション
      - 会話履歴テーブルのスキーマ定義

      ## 完了基準
      - data/assistant.db が自動生成される
      - テーブルが正常に作成される

  - id: 5
    title: "Task 5: Short-termメモリ（src/memory/short_term.py）"
    description: |
      ## 実装内容
      - LangGraph SqliteSaver Checkpointer の実装
      - get_checkpointer() でグラフに渡せる形式で返す
      - list_sessions() / delete_session() の実装

      ## 完了基準
      - tests/unit/test_short_term.py がパスする
      - セッション保存・ロード・削除が正常に動作する

  - id: 6
    title: "Task 6: Long-termメモリ（src/memory/long_term.py）"
    description: |
      ## 実装内容
      - ChromaDB による長期記憶の永続化
      - namespace 管理（user_profile / important_facts / task_context / conversation_summary）
      - save() / search() / delete() / list_all() の実装
      - 意味検索（Top-K件の類似メモリ取得）

      ## 完了基準
      - tests/unit/test_long_term.py がパスする
      - save後にsearchで取得できる

  - id: 7
    title: "Task 7: MemoryManager（src/memory/manager.py）"
    description: |
      ## 実装内容
      - ShortTermMemory + LongTermMemory の統合インターフェース
      - get_checkpointer() の委譲
      - get_relevant_context() による意味検索
      - save_memory() による長期記憶保存
      - build_context_messages() による LLM 向けメッセージ構築（max_history制限）

      ## 完了基準
      - tests/unit/test_memory_manager.py がパスする
      - max_historyを超えた場合に直近N件に制限される

  - id: 8
    title: "Task 8: BaseAgent（src/agents/base.py）"
    description: |
      ## 実装内容
      - 全エージェント共通の抽象基底クラス
      - run(state) の抽象メソッド定義
      - get_system_prompt() の抽象メソッド定義
      - _build_messages() の共通実装

      ## 完了基準
      - BaseAgent を継承したクラスが正常にインスタンス化できる

  - id: 9
    title: "Task 9: GeneralAgent（src/agents/general_agent.py）"
    description: |
      ## 実装内容
      - BaseAgent を継承した汎用会話エージェント
      - Claude API（Messages API）への接続
      - tool_use による save_to_memory ツール定義と実行
      - 会話履歴の更新処理

      ## 完了基準
      - tests/unit/test_general_agent.py がパスする（LLMモック使用）
      - ツール呼び出しありのケースで長期記憶が保存される

  - id: 10
    title: "Task 10: Router（src/orchestrator/router.py）"
    description: |
      ## 実装内容
      - Phase 1: 常に general_agent へルーティング
      - AGENT_MAP の定義（Phase 2以降の拡張用）
      - route(state) メソッドの実装

      ## 完了基準
      - tests/unit/test_router.py がパスする
      - 任意の入力で selected_agent = "general_agent" が返る

  - id: 11
    title: "Task 11: Orchestratorグラフ（src/orchestrator/graph.py）"
    description: |
      ## 実装内容
      - LangGraph StateGraph による メイングラフの構築
      - GraphState TypedDict の定義
      - ノード: input_processor / router / general_agent / response_formatter
      - SqliteSaver Checkpointer の組み込み
      - session_id による会話セッション管理

      ## 完了基準
      - tests/integration/test_graph_flow.py がパスする
      - セッション再開で会話履歴が復元される

  - id: 12
    title: "Task 12: CLIインターフェース（src/interface/cli.py）"
    description: |
      ## 実装内容
      - Rich を使用したインタラクティブCLI
      - poetry run assistant コマンドの実装
      - --resume / --session-id オプション
      - 特殊コマンド: /exit / /history / /memories / /sessions / /help

      ## 完了基準
      - poetry run assistant で起動する
      - テキストを入力すると Claude API 経由で応答が返る
      - --resume で前回の会話が復元される
      - /memories で保存済み長期記憶が表示される
```

---

## 4. `scripts/jira/create-phase-tickets.sh` の実装仕様

```bash
# 使用方法
./scripts/jira/create-phase-tickets.sh 1
# → Phase 1 の Epic と全Taskを作成してEpicに紐づける

# 処理フロー
# 1. data/jira/phase{N}-tickets.yaml を読み込む
# 2. Epic を作成 → EPIC_KEY を取得
# 3. tasks[] を順番に create-issue.sh で作成
# 4. 各 Task を link-task-to-epic.sh で Epic に紐づけ
# 5. 作成結果のサマリーを表示

# 出力例
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#   Phase 1 チケット作成完了
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Epic:  SA-1
# Tasks: SA-2 SA-3 SA-4 ... SA-13
# URL:   https://kencom2400.atlassian.net/browse/SA-1
```

YAMLのパースには Python3（標準インストール済み）を使用する（jqはYAML非対応のため）。

---

## 5. .gitignore への追記内容

```gitignore
# JIRA認証情報
scripts/jira/config.local.sh
```

---

## 6. 実装順序

```
1. scripts/jira/config.sh
2. scripts/jira/config.local.sh.example
3. scripts/jira/common.sh
4. scripts/jira/issues/get-issue-types.sh   ← 接続確認に使用
5. scripts/jira/issues/create-issue.sh
6. scripts/jira/issues/get-issue.sh
7. scripts/jira/issues/link-task-to-epic.sh
8. data/jira/phase1-tickets.yaml
9. scripts/jira/create-phase-tickets.sh
10. .gitignore への追記
```

---

## 7. 完了基準

- [ ] `./scripts/jira/issues/get-issue-types.sh SA` でIssue種別一覧が取得できる
- [ ] `./scripts/jira/create-phase-tickets.sh 1` でPhase 1の Epic + 12 Tasks が作成される
- [ ] 全TaskがJIRA上でEpicに紐づいている
- [ ] `config.local.sh` が Git にコミットされていない（`git status` で表示されない）
