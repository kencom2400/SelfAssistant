import numpy as np
import pytest

from self_assistant.memory.embeddings import EmbeddingModel


@pytest.fixture
def mock_model(mocker):
    """SentenceTransformerのロードをモックして固定ベクトルを返す"""
    dim = 384
    fake_vector = np.ones(dim, dtype=np.float32)

    mock_st = mocker.MagicMock()
    mock_st.encode.return_value = fake_vector

    mocker.patch(
        "self_assistant.memory.embeddings.SentenceTransformer",
        return_value=mock_st,
    )
    return mock_st, dim


@pytest.fixture
def mock_model_batch(mocker):
    """バッチ用モック：複数ベクトルを返す"""
    dim = 384
    texts_count = 3
    fake_matrix = np.ones((texts_count, dim), dtype=np.float32)

    mock_st = mocker.MagicMock()
    mock_st.encode.return_value = fake_matrix

    mocker.patch(
        "self_assistant.memory.embeddings.SentenceTransformer",
        return_value=mock_st,
    )
    return mock_st, dim, texts_count


class TestEmbeddingModel:
    def test_default_model_name(self):
        em = EmbeddingModel()
        assert em.model_name == "intfloat/multilingual-e5-small"

    def test_custom_model_name(self):
        em = EmbeddingModel(model_name="custom-model")
        assert em.model_name == "custom-model"

    def test_lazy_load(self, mocker):
        mock_st_class = mocker.patch("self_assistant.memory.embeddings.SentenceTransformer")
        em = EmbeddingModel()
        mock_st_class.assert_not_called()
        mock_st_class.return_value.encode.return_value = np.ones(384, dtype=np.float32)
        em.encode("test")
        mock_st_class.assert_called_once_with("intfloat/multilingual-e5-small")

    def test_model_loaded_once(self, mock_model):
        mock_st, _ = mock_model
        em = EmbeddingModel()
        em.encode("first")
        em.encode("second")
        # SentenceTransformerのコンストラクタは1回だけ
        from self_assistant.memory import embeddings as emb_mod
        assert em._model is mock_st

    def test_encode_returns_list(self, mock_model):
        em = EmbeddingModel()
        result = em.encode("テストテキスト")
        assert isinstance(result, list)

    def test_encode_dimension(self, mock_model):
        _, dim = mock_model
        em = EmbeddingModel()
        result = em.encode("テストテキスト")
        assert len(result) == dim

    def test_encode_elements_are_float(self, mock_model):
        em = EmbeddingModel()
        result = em.encode("テストテキスト")
        assert all(isinstance(v, float) for v in result)

    def test_encode_batch_returns_list_of_lists(self, mock_model_batch):
        mock_st, dim, count = mock_model_batch
        mock_st.encode.return_value = np.ones((count, dim), dtype=np.float32)
        em = EmbeddingModel()
        texts = ["テキスト1", "テキスト2", "テキスト3"]
        result = em.encode_batch(texts)
        assert isinstance(result, list)
        assert len(result) == count
        assert all(isinstance(vec, list) for vec in result)

    def test_encode_batch_dimension(self, mock_model_batch):
        mock_st, dim, count = mock_model_batch
        mock_st.encode.return_value = np.ones((count, dim), dtype=np.float32)
        em = EmbeddingModel()
        result = em.encode_batch(["a", "b", "c"])
        assert all(len(vec) == dim for vec in result)

    def test_encode_calls_with_convert_to_numpy(self, mock_model):
        mock_st, _ = mock_model
        em = EmbeddingModel()
        em.encode("hello")
        mock_st.encode.assert_called_once_with("hello", convert_to_numpy=True)

    def test_encode_batch_calls_with_convert_to_numpy(self, mock_model_batch):
        mock_st, dim, count = mock_model_batch
        mock_st.encode.return_value = np.ones((count, dim), dtype=np.float32)
        em = EmbeddingModel()
        texts = ["a", "b", "c"]
        em.encode_batch(texts)
        mock_st.encode.assert_called_once_with(texts, convert_to_numpy=True)
