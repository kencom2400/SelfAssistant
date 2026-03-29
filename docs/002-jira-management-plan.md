# 002 - JIRA管理 設計計画

## 概要

SelfAssistantプロジェクトのタスク管理をJIRAで行うための仕組みを構築する。
参照リポジトリ（MrWebDefence-Engine）の `scripts/jira/` の実装を移植し、
`001-agent-engine-plan.md` および `001-agent-engine-impl.md` の内容を
JIRAチケットとして登録・管理する。

---

## 1. 要件定義

### 1.1 機能要件

- JIRA Cloud（kencom2400.atlassian.net）へのAPI接続
- プロジェクト `SA` へのチケット作成・更新・参照
- Epic / Task の階層構造でチケットを管理
- 設計書（planファイル）からチケットを一括生成するスクリプト
- 認証情報をローカルファイルで管理し、Gitにコミットしない

### 1.2 非機能要件

| 項目 | 要件 |
|---|---|
| 接続方式 | REST API v3（Basic認証） |
| 使用ツール | curl + jq（シェルスクリプト） |
| 認証情報管理 | `scripts/jira/config.local.sh`（.gitignore対象） |
| プロジェクトキー | `SA` |
| JIRA URL | `https://kencom2400.atlassian.net` |

---

## 2. 接続設計

### 2.1 認証方式

参照リポジトリと同じ Basic認証を使用する。

```
Authorization: Basic base64(JIRA_EMAIL:JIRA_API_TOKEN)
```

### 2.2 設定ファイル構成

```
scripts/jira/
├── config.local.sh.example   # テンプレート（Gitに含める）
├── config.local.sh           # 実際の認証情報（.gitignore対象）
└── config.sh                 # 共通設定（JIRA_BASE_URL等）
```

**config.local.sh.example の内容:**
```bash
#!/bin/bash
# このファイルをコピーして config.local.sh を作成してください
# cp scripts/jira/config.local.sh.example scripts/jira/config.local.sh

export JIRA_EMAIL='your-email@example.com'
export JIRA_API_TOKEN='your-api-token'
```

**config.sh の内容:**
```bash
#!/bin/bash
export JIRA_BASE_URL='https://kencom2400.atlassian.net'
export JIRA_PROJECT_KEY='SA'
```

---

## 3. スクリプト構成

### 3.1 ディレクトリ構成

```
scripts/
└── jira/
    ├── common.sh                    # 共通関数（API呼び出し・認証）
    ├── config.sh                    # 共通設定
    ├── config.local.sh.example     # 認証情報テンプレート
    ├── config.local.sh             # 認証情報（.gitignore）
    ├── issues/
    │   ├── create-issue.sh         # チケット作成
    │   ├── get-issue.sh            # チケット参照
    │   ├── get-issue-types.sh      # Issue種別一覧取得
    │   └── link-task-to-epic.sh    # EpicへのTask紐づけ
    │   # update-issue.sh は Phase 2 以降で実装予定
    └── create-phase-tickets.sh     # フェーズ単位の一括チケット作成
```

### 3.2 共通関数（common.sh）

参照リポジトリの実装をそのまま移植する：

- `check_jira_auth()` - 認証情報の存在確認
- `get_auth_header()` - Base64エンコードのBasic認証ヘッダー生成
- `jira_api_call(method, endpoint, data)` - REST API呼び出し共通関数
- `handle_jira_error(response)` - エラーレスポンスの解析・表示
- `get_issue_type_id_from_api(project_key, type_name)` - Issue種別IDの動的取得
- `map_status_name(status_name)` - ステータス名の正規化（英語→日本語）

---

## 4. チケット構成設計

### 4.1 Phase 1 のチケット階層

`001-agent-engine-impl.md` の実装ステップを基に以下の構成でチケットを作成する。

```
[Epic] Phase 1: CLIエージェントエンジン基盤構築
  │
  ├── [Task] 1. 環境構築（pyenv + poetry + pyproject.toml）
  ├── [Task] 2. 設定管理（src/config/settings.py）
  ├── [Task] 3. Embeddingsモジュール（src/memory/embeddings.py）
  ├── [Task] 4. データベース基盤（src/tools/database.py）
  ├── [Task] 5. Short-termメモリ（src/memory/short_term.py）
  ├── [Task] 6. Long-termメモリ（src/memory/long_term.py）
  ├── [Task] 7. MemoryManager（src/memory/manager.py）
  ├── [Task] 8. BaseAgent（src/agents/base.py）
  ├── [Task] 9. GeneralAgent（src/agents/general_agent.py）
  ├── [Task] 10. Router（src/orchestrator/router.py）
  ├── [Task] 11. Orchestratorグラフ（src/orchestrator/graph.py）
  └── [Task] 12. CLIインターフェース（src/interface/cli.py）
```

### 4.2 各チケットの記載内容

| フィールド | 内容 |
|---|---|
| Summary | `Task N: {モジュール名}（{ファイルパス}）` |
| Issue Type | Epic / Task |
| Status | ToDo（作成時） |
| Description | 実装内容・完了基準（impl.mdの該当セクションから） |

### 4.3 一括作成スクリプト（create-phase-tickets.sh）

```bash
# 使用方法
./scripts/jira/create-phase-tickets.sh 1
# → Phase 1 の Epic を作成し、12個のTaskを作成してEpicに紐づける
```

処理フロー：
1. Epic を作成し、EPIC_KEY を取得
2. 各 Task を create-issue.sh で作成
3. link-task-to-epic.sh で Epic に紐づけ
4. 作成結果のサマリーを表示

---

## 5. .gitignore 追加内容

```gitignore
# JIRA認証情報
scripts/jira/config.local.sh
```

---

## 6. 完了基準

- [ ] `scripts/jira/` 以下のスクリプトが動作する
- [ ] `config.local.sh` を設定することでJIRAに接続できる
- [ ] Phase 1 の Epic と 12個の Task がJIRAに作成される
- [ ] 全TaskがEpicに紐づいている
- [ ] `config.local.sh` がGitにコミットされていない
