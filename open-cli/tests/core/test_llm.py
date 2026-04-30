import pytest
from core.llm import LLMClient, LLMError

def test_llm_client_initialization():
    config = {"anthropic_api_key": "test-key", "minimax_model": "MiniMax-M2.7", "anthropic_base_url": "https://api.minimaxi.com/anthropic"}
    client = LLMClient(config=config)
    assert client.model == "MiniMax-M2.7"

def test_llm_client_default_base_url():
    config = {"anthropic_api_key": "test-key", "minimax_model": "MiniMax-M2.7", "anthropic_base_url": "https://api.minimaxi.com/anthropic"}
    client = LLMClient(config=config)
    assert client.base_url == "https://api.minimaxi.com/anthropic"

def test_llm_error_on_missing_api_key():
    config = {"anthropic_api_key": "", "minimax_model": "MiniMax-M2.7", "anthropic_base_url": "https://api.minimaxi.com/anthropic"}
    with pytest.raises(LLMError):
        LLMClient(config=config)