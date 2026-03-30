from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

# プロジェクトルート（このファイルから3階層上）
_PROJECT_ROOT = Path(__file__).parent.parent.parent.parent


class Settings(BaseSettings):
    # Claude API
    anthropic_api_key: str
    model: str = "claude-sonnet-4-6"
    max_tokens: int = 4096

    # Memory（環境変数未設定時はプロジェクトルート基準の絶対パスを使用）
    db_path: str = str(_PROJECT_ROOT / "data" / "assistant.db")
    chroma_path: str = str(_PROJECT_ROOT / "data" / "chroma")
    embedding_model: str = "intfloat/multilingual-e5-small"
    max_history: int = 20
    long_term_top_k: int = 3

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()
