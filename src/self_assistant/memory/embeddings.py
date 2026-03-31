from __future__ import annotations

from sentence_transformers import SentenceTransformer


class EmbeddingModel:
    def __init__(self, model_name: str = "intfloat/multilingual-e5-small") -> None:
        self.model_name = model_name
        self._model: SentenceTransformer | None = None

    def _load(self) -> SentenceTransformer:
        if self._model is None:
            self._model = SentenceTransformer(self.model_name)
        return self._model

    def encode(self, text: str) -> list[float]:
        """テキストをベクトルに変換する"""
        return self._load().encode(text, convert_to_numpy=True).tolist()

    def encode_batch(self, texts: list[str]) -> list[list[float]]:
        """複数テキストをまとめてベクトルに変換する"""
        return self._load().encode(texts, convert_to_numpy=True).tolist()
