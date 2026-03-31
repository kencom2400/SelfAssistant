from pathlib import Path

import pytest
from sqlalchemy.ext.asyncio import AsyncEngine

from self_assistant.tools.database import get_engine


class TestGetEngine:
    def test_returns_async_engine(self, tmp_path):
        db_path = str(tmp_path / "test.db")
        engine = get_engine(db_path)
        assert isinstance(engine, AsyncEngine)

    def test_creates_parent_directory(self, tmp_path):
        db_path = str(tmp_path / "nested" / "dir" / "test.db")
        get_engine(db_path)
        assert Path(db_path).parent.exists()

    def test_engine_url_contains_path(self, tmp_path):
        db_path = str(tmp_path / "assistant.db")
        engine = get_engine(db_path)
        assert db_path in str(engine.url)

    def test_engine_dialect_is_sqlite(self, tmp_path):
        db_path = str(tmp_path / "test.db")
        engine = get_engine(db_path)
        assert engine.dialect.name == "sqlite"

    def test_existing_directory_does_not_raise(self, tmp_path):
        db_path = str(tmp_path / "test.db")
        # 2回呼んでも例外が出ない
        get_engine(db_path)
        get_engine(db_path)

    @pytest.mark.asyncio
    async def test_engine_can_connect(self, tmp_path):
        db_path = str(tmp_path / "test.db")
        engine = get_engine(db_path)
        async with engine.connect() as conn:
            result = await conn.execute(__import__("sqlalchemy").text("SELECT 1"))
            assert result.scalar() == 1
        await engine.dispose()
