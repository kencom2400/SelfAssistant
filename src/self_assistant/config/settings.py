from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # Claude API
    anthropic_api_key: str
    model: str = "claude-sonnet-4-6"
    max_tokens: int = 4096

    # Memory
    db_path: str = "data/assistant.db"
    chroma_path: str = "data/chroma"
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
