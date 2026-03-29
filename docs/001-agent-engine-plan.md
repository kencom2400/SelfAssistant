# 001 - Self Assistant Agent Engine 要件定義・設計計画

## 概要

ユーザーの日常的な活動全般をサポートするマルチエージェントエンジン。
タスク管理・情報収集・コード生成・スケジュール管理など幅広い用途に対応し、
スケジュールトリガー・イベントトリガーによる自動活動と、ユーザーとの対話を組み合わせた
インテリジェントなアシスタントを実現する。

---

## 1. 要件定義

### 1.1 機能要件

#### ユーザー対話機能
- ユーザーからの自然言語による質問・指示を受け付ける
- 適切なエージェントにルーティングし、回答・実行結果を返す
- 会話履歴を保持し、文脈を踏まえた応答を行う

#### 自動活動機能
- スケジュールトリガー：指定時刻・間隔で自動タスクを実行
- イベントトリガー：ファイル変更・外部イベントを検知して自動実行
- 実行結果をユーザーに通知（CLI → 将来的にSlack/LINE）

#### サポート対象タスク（初期スコープ）
- タスク・TODO管理
- 情報収集・要約
- コード生成・レビュー支援
- スケジュール管理
- 汎用Q&A・相談

#### 拡張性
- 新しい専門エージェントを容易に追加できる構造
- 外部API連携を後から組み込める設計

### 1.2 非機能要件

| 項目 | 要件 |
|------|------|
| 言語 | Python 3.12.x (pyenv管理) |
| フレームワーク | LangGraph |
| LLM | Claude API (Anthropic) |
| インターフェース | Phase 1: CLI / Phase 2: Slack or LINE |
| デプロイ | Phase 1: ローカル環境 |
| 状態永続化 | SQLite（ローカル） |
| トリガー | スケジュール (cron-like) / イベント駆動 |

---

## 2. アーキテクチャ設計

### 2.1 全体構成：4層マルチエージェント

```
┌─────────────────────────────────────────────────┐
│              Layer 1: Interface Layer            │
│         CLI (→ 将来: Slack / LINE)               │
└─────────────────┬───────────────────────────────┘
                  │ ユーザー入力 / トリガーイベント
┌─────────────────▼───────────────────────────────┐
│           Layer 2: Orchestrator Layer            │
│  - タスク解釈・分解                               │
│  - エージェントルーティング                       │
│  - 会話状態管理                                   │
│  - 実行計画立案                                   │
└──────┬──────────┬──────────┬────────────────────┘
       │          │          │
┌──────▼──┐ ┌────▼────┐ ┌──▼──────────────────────┐
│ Layer 3 │ │ Layer 3 │ │      Layer 3             │
│ Task    │ │ Info    │ │  Code / Schedule / ...   │
│ Agent   │ │ Agent   │ │  Specialized Agents      │
└──────┬──┘ └────┬────┘ └──┬──────────────────────┘
       │          │         │
┌──────▼──────────▼─────────▼──────────────────────┐
│              Layer 4: Tool / Resource Layer       │
│  ファイルシステム / Web検索 / コード実行 /          │
│  スケジューラー / 外部API（拡張用）                │
└───────────────────────────────────────────────────┘
```

### 2.2 各層の詳細設計

#### Layer 1: Interface Layer

**役割**: ユーザーとのI/O、トリガー受信

| コンポーネント | 説明 |
|---|---|
| `CLIInterface` | ユーザー入力受付・結果表示（Rich使用でリッチ表示） |
| `ScheduleTrigger` | cron形式のスケジュールタスク管理・実行 |
| `EventTrigger` | ファイル変更・外部イベント検知 |
| `NotificationHandler` | 実行結果の通知（CLI出力 → 将来Slack/LINE） |

**将来拡張**: `SlackInterface`, `LineInterface` を同インターフェースに準拠して追加

#### Layer 2: Orchestrator Layer

**役割**: リクエスト解釈・エージェント振り分け・全体フロー管理

| コンポーネント | 説明 |
|---|---|
| `MainOrchestrator` | LangGraphのメイングラフ。全体のフロー制御 |
| `TaskRouter` | リクエスト内容を解析し適切なエージェントへルーティング |
| `ConversationMemory` | 会話履歴・コンテキスト管理 |
| `ExecutionPlanner` | 複数エージェント連携が必要な場合の実行計画立案 |

#### Layer 3: Specialized Agent Layer

**役割**: ドメイン特化の処理実行

| エージェント | 役割 |
|---|---|
| `TaskManagementAgent` | TODO作成・更新・一覧・優先度管理 |
| `InformationAgent` | 情報収集・要約・検索 |
| `CodeAgent` | コード生成・レビュー・説明 |
| `ScheduleAgent` | スケジュール登録・リマインド |
| `GeneralAgent` | 上記に当てはまらない汎用Q&A・相談 |

各エージェントは共通の `BaseAgent` インターフェースを継承し、独立したLangGraphサブグラフとして実装する。

#### Layer 4: Tool / Resource Layer

**役割**: 実際のツール実行・外部リソースアクセス

| ツール | 説明 |
|---|---|
| `FileSystemTool` | ファイル読み書き・タスクデータ永続化 |
| `WebSearchTool` | Web情報収集（DuckDuckGo等） |
| `CodeExecutionTool` | Pythonコードの安全な実行 |
| `SchedulerTool` | スケジュール登録・管理（APScheduler） |
| `DatabaseTool` | SQLiteによる状態・履歴の永続化 |
| `ExternalAPITool` | 外部API呼び出しの抽象インターフェース（拡張用） |

---

## 3. LangGraph グラフ設計

### 3.1 メイングラフ（Orchestrator）

```
[START]
   │
   ▼
[input_processor]      ← ユーザー入力・トリガー情報の正規化
   │
   ▼
[router]               ← タスク種別の判定・エージェント選択
   │
   ├─→ [task_agent_subgraph]
   ├─→ [info_agent_subgraph]
   ├─→ [code_agent_subgraph]
   ├─→ [schedule_agent_subgraph]
   └─→ [general_agent_subgraph]
          │
          ▼
   [response_formatter]  ← 結果の整形・ユーザー向け回答生成
          │
          ▼
        [END]
```

### 3.2 状態スキーマ（GraphState）

```python
class GraphState(TypedDict):
    # 入力
    user_input: str
    trigger_type: str          # "user" | "schedule" | "event"
    trigger_metadata: dict

    # ルーティング
    intent: str                # 判定されたインテント
    selected_agent: str        # ルーティング先エージェント
    execution_plan: list[str]  # 複数エージェント連携時の実行順

    # 実行コンテキスト
    conversation_history: list[dict]
    agent_results: dict        # 各エージェントの実行結果
    current_step: str

    # 出力
    final_response: str
    error: Optional[str]
```

### 3.3 サブグラフ設計（各専門エージェント）

各専門エージェントは独立したサブグラフとして実装：

```
[agent_start]
   │
   ▼
[context_builder]   ← 必要なコンテキスト収集
   │
   ▼
[llm_reasoning]     ← Claude APIによる推論・計画
   │
   ├─ ツール呼び出しあり → [tool_execution] → [llm_reasoning]（ループ）
   │
   └─ 完了 → [result_validator]  ← 結果検証・品質チェック
                  │
                  ▼
             [agent_end]
```

### 3.4 Phase 1 シーケンス（最小構成）

```
ユーザー          CLI              Orchestrator       GeneralAgent      Claude API
  │               │                    │                   │                │
  │ テキスト入力   │                    │                   │                │
  │──────────────▶│                    │                   │                │
  │               │ invoke(state)      │                   │                │
  │               │───────────────────▶│                   │                │
  │               │                    │ input_processor   │                │
  │               │                    │──────────────┐    │                │
  │               │                    │◀─────────────┘    │                │
  │               │                    │ router            │                │
  │               │                    │──────────────┐    │                │
  │               │                    │◀─────────────┘    │                │
  │               │                    │ run(state)        │                │
  │               │                    │──────────────────▶│                │
  │               │                    │                   │ messages API   │
  │               │                    │                   │───────────────▶│
  │               │                    │                   │◀───────────────│
  │               │                    │◀──────────────────│                │
  │               │◀───────────────────│                   │                │
  │◀──────────────│                    │                   │                │
  │ 回答表示       │                    │                   │                │
```

### 3.5 会話履歴の管理方針

- `conversation_history` は `list[dict]` 形式で `{"role": "user"|"assistant", "content": str}` を保持
- セッション単位でSQLiteに永続化し、次回起動時にロード可能
- コンテキストウィンドウ超過を防ぐため、直近N件（デフォルト20件）のみLLMに渡す

---

## 4. ディレクトリ構成

```
SelfAssistant/
├── docs/
│   ├── 001-agent-engine-plan.md      ← 本ファイル
│   └── 001-agent-engine-result.md    ← 実装結果（実装後作成）
│
├── src/
│   ├── __init__.py
│   │
│   ├── interface/                    # Layer 1
│   │   ├── __init__.py
│   │   ├── cli.py                    # CLIインターフェース
│   │   ├── triggers.py               # スケジュール・イベントトリガー
│   │   └── notification.py           # 通知ハンドラー
│   │
│   ├── orchestrator/                 # Layer 2
│   │   ├── __init__.py
│   │   ├── graph.py                  # メインLangGraphグラフ
│   │   ├── router.py                 # エージェントルーター
│   │   ├── memory.py                 # 会話メモリ管理
│   │   └── planner.py                # 実行プランナー
│   │
│   ├── agents/                       # Layer 3
│   │   ├── __init__.py
│   │   ├── base.py                   # BaseAgentクラス
│   │   ├── task_agent.py             # タスク管理エージェント
│   │   ├── info_agent.py             # 情報収集エージェント
│   │   ├── code_agent.py             # コード支援エージェント
│   │   ├── schedule_agent.py         # スケジュールエージェント
│   │   └── general_agent.py          # 汎用エージェント
│   │
│   ├── tools/                        # Layer 4
│   │   ├── __init__.py
│   │   ├── filesystem.py             # ファイルシステムツール
│   │   ├── websearch.py              # Web検索ツール
│   │   ├── code_exec.py              # コード実行ツール
│   │   ├── scheduler.py              # スケジューラーツール
│   │   ├── database.py               # DB操作ツール
│   │   └── base_api.py               # 外部API基底クラス
│   │
│   └── config/
│       ├── __init__.py
│       └── settings.py               # 設定管理（環境変数等）
│
├── data/                             # ローカルデータ永続化
│   ├── tasks.db                      # SQLiteデータベース
│   └── schedules/                    # スケジュール定義ファイル
│
├── tests/
│   ├── unit/
│   └── integration/
│
├── .env.example                      # 環境変数テンプレート
├── requirements.txt
├── pyproject.toml
└── README.md
```

---

## 5. 技術スタック

### 環境管理
| ツール | バージョン | 用途 |
|---|---|---|
| `pyenv` | 2.6.11 | Pythonバージョン管理 |
| `poetry` | 2.2.1 | 依存関係・パッケージ管理 |
| Python | 3.12.x | 実行環境（3.13は互換性リスクのため3.12を採用） |

### ライブラリ
| カテゴリ | ライブラリ | 用途 |
|---|---|---|
| エージェントフレームワーク | `langgraph` | マルチエージェントグラフ管理 |
| LLM | `anthropic` | Claude API クライアント |
| LLM統合 | `langchain-anthropic` | LangChain-Claude統合 |
| CLI | `rich` | リッチなCLI表示 |
| CLI入力 | `click` | CLIコマンド定義 |
| スケジューラー | `apscheduler` | スケジュールトリガー |
| イベント監視 | `watchdog` | ファイルイベント監視 |
| DB | `sqlalchemy` + `aiosqlite` | 非同期SQLiteアクセス |
| 設定管理 | `pydantic-settings` | 環境変数・設定管理 |
| Web検索 | `duckduckgo-search` | 情報収集ツール |
| YAML管理 | `pyyaml` | スケジュール定義ファイル読み込み |
| テスト | `pytest` + `pytest-asyncio` | テストフレームワーク |

### スケジュール定義
自動活動のスケジュールは `data/schedules/` 以下のYAMLファイルで管理する。

```yaml
# data/schedules/example.yaml
schedules:
  - id: daily_summary
    name: 日次サマリー
    trigger:
      type: cron
      hour: 9
      minute: 0
    task:
      agent: general
      prompt: "今日のタスク一覧を確認してサマリーを作成してください"
    enabled: true
```

---

## 6. 実装フェーズ計画

### Phase 1: 基盤構築（最初の実装）
- [ ] プロジェクト初期化（pyproject.toml, requirements.txt）
- [ ] 設定管理（`config/settings.py`）
- [ ] Layer 4: 基本ツール実装（DB, ファイルシステム）
- [ ] Layer 3: BaseAgent + GeneralAgent（汎用会話）
- [ ] Layer 2: Orchestrator基本グラフ（シングルエージェント動作）
- [ ] Layer 1: CLIインターフェース（対話モード）
- [ ] 動作確認：CLIでの基本会話

### Phase 2: 専門エージェント追加
- [ ] TaskManagementAgent + TaskDB
- [ ] InformationAgent + WebSearchTool
- [ ] CodeAgent + CodeExecutionTool
- [ ] ScheduleAgent + APScheduler統合
- [ ] Orchestratorルーティング強化

### Phase 3: 自動活動機能
- [ ] ScheduleTrigger実装
- [ ] EventTrigger実装（watchdog）
- [ ] 通知システム

### Phase 4: 外部インターフェース拡張
- [ ] Slack連携
- [ ] LINE連携

---

## 7. 主要設計方針

### エージェント間通信
- LangGraphの`State`を通じて情報を受け渡し
- エージェントは`GraphState`を読み取り・更新するノードとして実装
- サブグラフは独立してテスト可能な単位とする

### 拡張性の確保
- 新しい専門エージェントは`BaseAgent`を継承しルーター設定を追加するだけで組み込み可能
- 外部APIは`base_api.py`の抽象クラスを実装する形で追加
- インターフェース層は共通の`BaseInterface`プロトコルに準拠

### Claude API活用方針
- オーケストレーターと各エージェントそれぞれにClaude APIを使用
- システムプロンプトでエージェントごとの役割・制約を定義
- ツール呼び出し（Function Calling）を活用してLayer 4ツールを実行

---

## 8. テスト方針

### テスト構成
```
tests/
├── conftest.py               # 共通フィクスチャ（モックLLM、テストDB等）
├── unit/
│   ├── test_settings.py      # 設定管理のテスト
│   ├── test_database.py      # DBツールのテスト
│   ├── test_router.py        # ルーティングロジックのテスト
│   ├── test_general_agent.py # GeneralAgentのテスト
│   └── test_cli.py           # CLIコマンドのテスト
└── integration/
    └── test_graph_flow.py    # Orchestratorグラフ全体フローのテスト
```

### テスト方針
- **実装と同時作成**: 各モジュール実装時に対応するテストを作成
- **LLMモック**: Claude API呼び出しはモックに差し替えてユニットテスト
- **DBはインメモリ**: テスト用DBはインメモリSQLiteを使用（`:memory:`）
- **非同期テスト**: `pytest-asyncio` を使用して非同期コードをテスト
- **カバレッジ**: `pytest-cov` でカバレッジ計測

---

## 9. 未決定事項・今後の検討項目

| 項目 | 内容 |
|---|---|
| 認証・セキュリティ | コード実行サンドボックスの方式 |
| ログ管理 | 実行ログの保存先・ローテーション方針 |
| エラーリカバリー | エージェント失敗時のフォールバック戦略 |
| Slack/LINE移行タイミング | Phase 1完了後に判断 |
