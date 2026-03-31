from __future__ import annotations

from pathlib import Path

from sqlalchemy.ext.asyncio import AsyncEngine, create_async_engine


def get_engine(db_path: str) -> AsyncEngine:
    """SQLite 非同期エンジンを返す。DB ファイルの親ディレクトリを自動作成する。"""
    Path(db_path).parent.mkdir(parents=True, exist_ok=True)
    return create_async_engine(f"sqlite+aiosqlite:///{db_path}", echo=False)
