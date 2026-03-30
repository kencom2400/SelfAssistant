# 001 - Self Assistant Agent Engine 実装設計書（Phase 1）

## 対象フェーズ

Phase 1: CLIで会話できる最小構成
- Working Memory / Short-term Memory / Long-term Memory の基盤構築
- GeneralAgent による汎用会話
- セッション再開・長期記憶の保存と意味検索

---

## 1. 環境構築手順

```bash
# Python 3.12.12 をプロジェクトローカルに設定
pyenv local 3.12.12

# Poetry プロジェクト初期化
poetry init

# 仮想環境をプロジェクト内に作成（任意・推奨）
poetry config virtualenvs.in-project true

# 依存パッケージインストール
poetry install
```

### pyproject.toml 構成

```toml
[tool.poetry]
name = "self-assistant"
version = "0.1.0"
description = "Personal AI assistant engine"
authors = ["kencom"]
packages = [{ include = "src" }]

[tool.poetry.dependencies]
python = "^3.12"
langgraph = "^0.2"
langchain-anthropic = "^0.3"
anthropic = "^0.49"
rich = "^13"
click = "^8"
pydantic-settings = "^2"
sqlalchemy = "^2"
aiosqlite = "^0.20"
chromadb = "^0.6"
sentence-transformers = "^3"
pyyaml = "^6"

[tool.poetry.group.dev.dependencies]
pytest = "^8"
pytest-asyncio = "^0.23"
pytest-cov = "^5"
pytest-mock = "^3"

[tool.poetry.scripts]
assistant = "src.interface.cli:main"

[tool.pytest.ini_options]
asyncio_mode = "auto"
testpaths = ["tests"]
addopts = "--cov=src --cov-report=term-missing"

[build-system]
requires = ["poetry-core"]
build-backend = "poetry.core.masonry.api"
```

---

## 2. ディレクトリ構成（Phase 1 対象）

```
SelfAssistant/
├── src/
│   └── self_assistant/          # Pythonパッケージルート
│       ├── __init__.py
│       ├── config/
│       │   ├── __init__.py
│       │   └── settings.py
│       ├── memory/
│       │   ├── __init__.py
│       │   ├── manager.py
│       │   ├── short_term.py
│       │   ├── long_term.py
│       │   └── embeddings.py
│       ├── tools/
│       │   ├── __init__.py
│       │   └── database.py
│       ├── agents/
│       │   ├── __init__.py
│       │   ├── base.py
│       │   └── general_agent.py
│       ├── orchestrator/
│       │   ├── __init__.py
│       │   ├── graph.py
│       │   └── router.py
│       └── interface/
│           ├── __init__.py
│           └── cli.py
├── data/
│   ├── assistant.db       # 自動生成
│   └── chroma/            # 自動生成
├── tests/
│   ├── conftest.py
│   ├── unit/
│   │   ├── test_settings.py
│   │   ├── test_embeddings.py
│   │   ├── test_short_term.py
│   │   ├── test_long_term.py
│   │   ├── test_memory_manager.py
│   │   ├── test_router.py
│   │   └── test_general_agent.py
│   └── integration/
│       └── test_graph_flow.py
├── .env
├── .env.example
├── .python-version        # pyenv: 3.12.12
└── pyproject.toml
```

---

## 3. モジュール詳細設計

### 3.1 `src/config/settings.py`

アプリ全体の設定を pydantic-settings で管理。`.env` から自動ロード。

```python
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    # Claude API
    anthropic_api_key: str
    model: str = "claude-sonnet-4-6"
    max_tokens: int = 4096

    # メモリ
    db_path: str = "data/assistant.db"
    chroma_path: str = "data/chroma"
    embedding_model: str = "intfloat/multilingual-e5-small"
    max_history: int = 20          # LLMに渡す最大会話件数
    long_term_top_k: int = 3       # 意味検索で取得する最大件数

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

settings = Settings()
```

**.env.example**
```
ANTHROPIC_API_KEY=your-api-key-here
MODEL=claude-sonnet-4-6
```

---

### 3.2 `src/memory/embeddings.py`

sentence-transformers のラッパー。日本語対応の多言語モデルを使用。

```python
class EmbeddingModel:
    model_name: str  # "intfloat/multilingual-e5-small"
    _model: SentenceTransformer  # 遅延ロード

    def encode(self, text: str) -> list[float]:
        """テキストをベクトルに変換する"""

    def encode_batch(self, texts: list[str]) -> list[list[float]]:
        """複数テキストをまとめてベクトルに変換する"""
```

**モデル選定理由:** `intfloat/multilingual-e5-small`
- 日本語・英語の両方に対応
- モデルサイズが小さく（約117MB）ローカル実行に適している
- 精度と速度のバランスが良い

---

### 3.3 `src/memory/short_term.py`

LangGraph の SQLite Checkpointer を用いたセッション内会話履歴の管理。

```python
class ShortTermMemory:
    db_path: str

    def get_checkpointer(self) -> SqliteSaver:
        """LangGraph グラフに渡す Checkpointer を返す"""

    def list_sessions(self) -> list[dict]:
        """保存済みセッション一覧を返す（id, 開始日時, メッセージ数）"""

    def delete_session(self, session_id: str) -> None:
        """指定セッションの履歴を削除する"""
```

**セッションID:** UUID v4 を使用。CLI起動時に新規生成 or 再開指定。

---

### 3.4 `src/memory/long_term.py`

ChromaDB による長期記憶の永続化と意味検索。

```python
class LongTermMemory:
    chroma_path: str
    embedding_model: EmbeddingModel

    # namespace 定義
    NAMESPACES = ["user_profile", "important_facts", "task_context", "conversation_summary"]

    def save(self, content: str, namespace: str, metadata: dict = {}) -> str:
        """長期記憶を保存し、IDを返す"""
        # metadata には source（どのエージェントが保存したか）、
        # created_at（保存日時）を自動付与

    def search(self, query: str, namespace: str | None = None, n_results: int = 3) -> list[dict]:
        """意味検索でクエリに関連するメモリを返す"""
        # namespace=None のとき全 namespace を横断検索
        # 返り値: [{"content": str, "namespace": str, "metadata": dict, "distance": float}]

    def delete(self, memory_id: str) -> None:
        """指定IDのメモリを削除する"""

    def list_all(self, namespace: str | None = None) -> list[dict]:
        """保存済みメモリ一覧を返す（管理用）"""
```

---

### 3.5 `src/memory/manager.py`

Short-term / Long-term を統合する単一インターフェース。
各エージェントはこのクラスのみを通じてメモリにアクセスする。

```python
class MemoryManager:
    short_term: ShortTermMemory
    long_term: LongTermMemory

    def get_checkpointer(self) -> SqliteSaver:
        """Orchestrator グラフ初期化時に使用"""

    def get_relevant_context(self, query: str) -> list[dict]:
        """クエリに関連する長期記憶を取得する（意味検索）"""

    def save_memory(self, content: str, namespace: str, metadata: dict = {}) -> None:
        """エージェントが重要情報を長期記憶に保存する"""

    def build_context_messages(
        self,
        conversation_history: list[dict],
        relevant_memories: list[dict],
    ) -> list[dict]:
        """
        LLMに渡すメッセージリストを構築する。
        - relevant_memories をシステムプロンプトに注入
        - conversation_history は直近 max_history 件に制限
        """
```

---

### 3.6 `src/orchestrator/graph.py` の GraphState

```python
from typing import Annotated, Optional
from typing_extensions import TypedDict
from langgraph.graph.message import add_messages

class GraphState(TypedDict):
    # 入力
    session_id: str
    user_input: str
    trigger_type: str                    # "user" | "schedule" | "event"
    trigger_metadata: dict

    # ルーティング
    intent: str                          # 判定されたインテント
    selected_agent: str                  # ルーティング先

    # メモリ
    conversation_history: list[dict]     # {"role": str, "content": str}
    relevant_memories: list[dict]        # 意味検索で取得した長期記憶

    # 実行結果
    agent_results: dict
    final_response: str
    error: Optional[str]
```

---

### 3.7 `src/orchestrator/graph.py` のグラフ構成

```
[START]
   │
   ▼
[input_processor]
   │ ・session_id の確認/生成
   │ ・関連長期記憶を検索して state に注入
   ▼
[router]
   │ ・intent 判定（Phase 1 は常に "general"）
   │ ・selected_agent を state に設定
   ▼
[general_agent]
   │ ・会話履歴 + 長期記憶 + ユーザー入力を Claude API に送信
   │ ・応答を final_response に設定
   │ ・重要情報を自動検出して長期記憶へ保存
   ▼
[response_formatter]
   │ ・final_response の整形
   ▼
[END]
```

グラフは `SqliteSaver` を Checkpointer として使用し、
`config={"configurable": {"thread_id": session_id}}` でセッションを識別する。

---

### 3.8 `src/orchestrator/router.py`

```python
class Router:
    """
    Phase 1: 常に "general" を返す最小実装。
    Phase 2 以降: Claude API でインテント分類を行い専門エージェントへルーティング。
    """

    AGENT_MAP = {
        "general": "general_agent",
        # Phase 2 以降追加:
        # "task": "task_agent",
        # "info": "info_agent",
        # "code": "code_agent",
        # "schedule": "schedule_agent",
    }

    def route(self, state: GraphState) -> GraphState:
        """インテントを判定し selected_agent を返す"""
```

---

### 3.9 `src/agents/base.py`

```python
from abc import ABC, abstractmethod

class BaseAgent(ABC):
    """全エージェント共通の抽象基底クラス"""

    def __init__(self, memory_manager: MemoryManager, settings: Settings):
        self.memory = memory_manager
        self.settings = settings

    @abstractmethod
    async def run(self, state: GraphState) -> GraphState:
        """エージェントのメイン処理。state を受け取り更新した state を返す"""

    @abstractmethod
    def get_system_prompt(self) -> str:
        """エージェント固有のシステムプロンプト"""

    def _build_messages(self, state: GraphState) -> list[dict]:
        """会話履歴 + 長期記憶 + ユーザー入力を組み合わせてメッセージ列を構築"""
        return self.memory.build_context_messages(
            state["conversation_history"],
            state["relevant_memories"],
        )
```

---

### 3.10 `src/agents/general_agent.py`

```python
class GeneralAgent(BaseAgent):

    def get_system_prompt(self) -> str:
        return """
        あなたは親切で有能なパーソナルアシスタントです。
        ユーザーの日常的な活動全般をサポートします。
        会話の中でユーザーの重要な情報（好み、習慣、決定事項）を検出した場合は、
        long_term_memory ツールを使って保存してください。
        """

    async def run(self, state: GraphState) -> GraphState:
        """
        1. メッセージ列を構築（会話履歴 + 関連記憶）
        2. Claude API に送信（tool_use: long_term_memory_save）
        3. ツール呼び出しがあれば長期記憶に保存
        4. 最終応答を state["final_response"] に設定
        5. 会話履歴を更新
        """

    # Claude API に渡す tool 定義
    TOOLS = [
        {
            "name": "save_to_memory",
            "description": "重要な情報を長期記憶に保存する",
            "input_schema": {
                "type": "object",
                "properties": {
                    "content": {"type": "string", "description": "保存する内容"},
                    "namespace": {
                        "type": "string",
                        "enum": ["user_profile", "important_facts", "task_context"],
                        "description": "保存先カテゴリ"
                    },
                },
                "required": ["content", "namespace"],
            },
        }
    ]
```

---

### 3.11 `src/interface/cli.py`

Rich を使用したインタラクティブCLI。

```python
# コマンド体系
assistant          # 新規セッションで起動
assistant --resume # 前回のセッションを再開
assistant --session-id <id>  # 指定セッションを再開

# 会話中の特殊コマンド
/exit              # 終了
/history           # 現セッションの会話履歴を表示
/memories          # 保存済み長期記憶の一覧を表示
/sessions          # 過去セッション一覧を表示
/help              # ヘルプ表示
```

**表示仕様（Rich）:**
- ユーザー入力: `[bold cyan]You:[/]` プレフィックス
- アシスタント応答: `[bold green]Assistant:[/]` プレフィックス
- エラー: `[bold red]Error:[/]` プレフィックス
- 長期記憶保存時: `[dim]💾 記憶に保存しました[/]` をさりげなく表示

---

## 4. テスト設計

### 4.1 `tests/conftest.py`

```python
# 共通フィクスチャ
@pytest.fixture
def mock_anthropic(mocker):
    """Claude API 呼び出しをモック"""

@pytest.fixture
def in_memory_db():
    """テスト用インメモリ SQLite DB"""

@pytest.fixture
def mock_embedding_model(mocker):
    """sentence-transformers をモック（固定ベクトルを返す）"""

@pytest.fixture
def temp_chroma(tmp_path):
    """テスト用一時 ChromaDB"""
```

### 4.2 ユニットテスト一覧

| テストファイル | テスト内容 |
|---|---|
| `test_settings.py` | .env 読み込み・デフォルト値・バリデーション |
| `test_embeddings.py` | encode の出力形式・次元数・モックでの動作 |
| `test_short_term.py` | セッション保存・ロード・一覧・削除 |
| `test_long_term.py` | save・search（意味検索）・delete・list |
| `test_memory_manager.py` | get_relevant_context・build_context_messages（max_history制限） |
| `test_router.py` | Phase 1: 常に general を返す・AGENT_MAP の整合性 |
| `test_general_agent.py` | run の正常系・ツール呼び出しありの場合・長期記憶保存の確認 |

### 4.3 インテグレーションテスト

| テストファイル | テスト内容 |
|---|---|
| `test_graph_flow.py` | グラフ全体の実行・セッション再開（Checkpointer）・長期記憶の自動保存と次回会話への反映 |

---

## 5. 実装順序

依存関係を考慮した実装順序：

```
1. pyproject.toml + .env + .env.example
2. src/config/settings.py
   └── tests/unit/test_settings.py
3. src/memory/embeddings.py
   └── tests/unit/test_embeddings.py
4. src/tools/database.py（DBスキーマ・マイグレーション）
5. src/memory/short_term.py
   └── tests/unit/test_short_term.py
6. src/memory/long_term.py
   └── tests/unit/test_long_term.py
7. src/memory/manager.py
   └── tests/unit/test_memory_manager.py
8. src/agents/base.py
9. src/agents/general_agent.py
   └── tests/unit/test_general_agent.py
10. src/orchestrator/router.py
    └── tests/unit/test_router.py
11. src/orchestrator/graph.py
    └── tests/integration/test_graph_flow.py
12. src/interface/cli.py
    └── 動作確認（手動）
```

---

## 6. 完了基準

以下がすべて満たされた時点で Phase 1 完了とする：

- [ ] `poetry run assistant` でCLIが起動する
- [ ] テキストを入力すると Claude API を経由して応答が返る
- [ ] `--resume` オプションで前回の会話が復元される
- [ ] 会話の中で重要情報が自動的に長期記憶に保存される
- [ ] `/memories` コマンドで保存済み記憶が確認できる
- [ ] すべてのユニットテストがパスする
- [ ] インテグレーションテストがパスする
