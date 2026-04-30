import pytest
from core.llm import LLMClient, LLMError

def test_llm_client_initialization():
    client = LLMClient()
    assert client.model == "MiniMax-Text-01"

def test_llm_send_message():
    client = LLMClient()
    response = client.send([{"role": "user", "content": "Hello"}])
    assert isinstance(response, str)
    assert len(response) > 0

def test_llm_error_on_missing_api_key(monkeypatch):
    monkeypatch.delenv("MINIMAX_API_KEY", raising=False)
    client = LLMClient()
    with pytest.raises(LLMError):
        client.send([{"role": "user", "content": "test"}])