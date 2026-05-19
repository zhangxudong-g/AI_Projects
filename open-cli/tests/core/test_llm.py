import pytest
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))

from opencli.providers.minimax import MiniMaxProvider
from opencli.providers.base import BaseProvider


def test_minimax_provider_initialization():
    config = {"api_key": "test-key", "model": "MiniMax-M2.6", "base_url": "https://api.minimaxi.com/v1/text/chatcompletion_v2"}
    provider = MiniMaxProvider(api_key=config["api_key"], default_model=config["model"], base_url=config["base_url"])
    assert provider.default_model == "MiniMax-M2.6"
    assert provider.base_url == "https://api.minimaxi.com/v1/text/chatcompletion_v2"


def test_minimax_provider_name():
    provider = MiniMaxProvider(api_key="test-key", default_model="MiniMax-M2.6")
    assert provider.name == "minimax"


def test_minimax_provider_supports_streaming():
    provider = MiniMaxProvider(api_key="test-key", default_model="MiniMax-M2.6")
    assert provider.supports_streaming is True


def test_minimax_provider_supports_tools():
    provider = MiniMaxProvider(api_key="test-key", default_model="MiniMax-M2.6")
    assert provider.supports_tools is False


def test_provider_is_base_class():
    provider = MiniMaxProvider(api_key="test-key", default_model="MiniMax-M2.6")
    assert isinstance(provider, BaseProvider)
