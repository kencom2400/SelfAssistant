import pytest
from pydantic import ValidationError

from self_assistant.config.settings import Settings, get_settings


class TestSettings:
    def test_default_values(self):
        s = Settings(anthropic_api_key="test-key")
        assert s.model == "claude-sonnet-4-6"
        assert s.max_tokens == 4096
        assert s.db_path == "data/assistant.db"
        assert s.chroma_path == "data/chroma"
        assert s.embedding_model == "intfloat/multilingual-e5-small"
        assert s.max_history == 20
        assert s.long_term_top_k == 3

    def test_anthropic_api_key_required(self):
        with pytest.raises(ValidationError):
            Settings()

    def test_override_values(self):
        s = Settings(
            anthropic_api_key="my-key",
            model="claude-opus-4-6",
            max_tokens=1024,
            max_history=10,
            long_term_top_k=5,
        )
        assert s.anthropic_api_key == "my-key"
        assert s.model == "claude-opus-4-6"
        assert s.max_tokens == 1024
        assert s.max_history == 10
        assert s.long_term_top_k == 5

    def test_case_insensitive(self, monkeypatch):
        monkeypatch.setenv("ANTHROPIC_API_KEY", "env-key")
        monkeypatch.setenv("MAX_HISTORY", "15")
        s = Settings()
        assert s.anthropic_api_key == "env-key"
        assert s.max_history == 15

    def test_get_settings_returns_singleton(self, monkeypatch):
        monkeypatch.setenv("ANTHROPIC_API_KEY", "singleton-key")
        get_settings.cache_clear()
        s1 = get_settings()
        s2 = get_settings()
        assert s1 is s2
        get_settings.cache_clear()
